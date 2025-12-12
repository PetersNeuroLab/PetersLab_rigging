/**
 * wheel_onedirection_with_spike.ino
 * 单向阻尼 + 瞬时脉冲（脉冲预测性限幅以避免反向补偿）
 *
 * 重要：
 * - 若 DengFOC 库中读取速度 / 输出力矩 的函数名不同，
 *   请替换 DFOC_M0_Velocity() 与 DFOC_M0_setTorque(...) 为库中的正确函数名。
 * - 若你希望先编译检查但不操控电机，可在下面把 velocity/setTorque 的 stub 取消注释。
 */

#include "DengFOC.h"
#include <Arduino.h>

// ---------------- 硬件参数 ----------------
int Sensor_DIR = 1;          // 传感器方向（不对改为 -1）
int Motor_PP   = 6;          // 电机极对数
const int ENABLE_PIN = 12;   // 使能引脚

// ---------------- 阻尼参数 ----------------
float kp_damp    = 2.2f;     // 阻尼增益
float maxTorque  = 5.5f;     // 常规力矩限幅（单位依你的系统设定）
bool  damp_on_cw = true;     // true = 顺时针阻尼；false = 逆时针阻尼

// ----- 迟滞与斜坡参数（防抖） -----
float vel_on_threshold  = 0.2f;   // 进入阻尼阈值
float vel_off_threshold = 0.1f;   // 退出阻尼阈值
float torque_slew_rate  = 0.05f;  // 每次循环允许变化的最大力矩（绝对值）

// ---------------- 脉冲（瞬时阻尼）参数 ----------------
float spike_magnitude     = 8.0f;     // 脉冲幅度（正数）
float spike_max_limit     = 12.0f;    // 脉冲期间允许的最大绝对力矩（安全上限）
unsigned long spike_ms    = 50;       // 脉冲持续时间（毫秒）
float min_vel_for_spike   = 0.05f;    // 低速时不要触发脉冲（门限）

// ====== 预测性限幅参数（防止把速度翻转） ======
float J_est = 0.005f;  // 估计转动惯量（根据你的机械调整，越大越保守）

// ---------------- 内部状态 ----------------
float current_torque_out = 0.0f;
bool  damping_engaged = false;

bool  spike_active = false;
unsigned long spike_start_ms = 0;

float prev_vel = 0.0f;
unsigned long last_ms_global = 0;

// -------------------------------------------------
// 可选：临时存根（stub）用于仅编译/逻辑测试（不驱动实际电机）
// 如果你需要先编译通过并测试逻辑，把下面两行取消注释。
// 注意：启用 stub 后不会读取真实速度，也不会输出扭矩到电机。
//float DFOC_M0_Velocity() { return 0.0f; }
//void  DFOC_M0_setTorque(float t) { /* stub - 不输出 */ }
// -------------------------------------------------

void setup() {
  pinMode(ENABLE_PIN, OUTPUT);
  digitalWrite(ENABLE_PIN, HIGH);    // 使能驱动

  // 若 DengFOC 库需要初始化其它项，请在此添加
  DFOC_Vbus(12.6);                    // 设定驱动器供电电压
  DFOC_alignSensor(Motor_PP, Sensor_DIR);

  last_ms_global = millis();
}

void loop() {
  runFOC();               // 保持原有运行 FOC 循环（如果库示例中需要）
  SingleDirDamp_Mode();   // 我们的阻尼/脉冲逻辑
}

// ------------------ SingleDirDamp_Mode 实现 ------------------
void SingleDirDamp_Mode() {
    unsigned long now_ms = millis();

    // 1) 读取速度 —— 如果你的库函数名不同，请替换此行
    float vel = DFOC_M0_Velocity();   // <-- 替换为库实际的读速 API（或启用 stub）

    // 2) 判断目标方向与迟滞
    bool isCW = (vel > 0.0f);
    bool want_damp_direction = (damp_on_cw && isCW) || (!damp_on_cw && !isCW);
    float absvel = fabs(vel);

    if (want_damp_direction) {
        if (!damping_engaged && absvel >= vel_on_threshold) {
            damping_engaged = true;
        } else if (damping_engaged && absvel <= vel_off_threshold) {
            damping_engaged = false;
        }
    } else {
        damping_engaged = false;
    }

    // 3) 脉冲触发条件：符号变化或突然进入阻尼阈值
    bool sign_changed_to_target = false;
    if (damp_on_cw) {
        if (prev_vel <= 0.0f && vel > 0.0f) sign_changed_to_target = true;
    } else {
        if (prev_vel >= 0.0f && vel < 0.0f) sign_changed_to_target = true;
    }

    bool just_engaged_by_threshold = false;
    if (want_damp_direction && !spike_active) {
        if (absvel >= vel_on_threshold && fabs(prev_vel - vel) > 1e-6) {
            just_engaged_by_threshold = true;
        }
    }

    // 简单门限：低速时不要触发脉冲
    if ((sign_changed_to_target || just_engaged_by_threshold) && !spike_active && absvel >= min_vel_for_spike) {
        spike_active = true;
        spike_start_ms = now_ms;
    }
    if (spike_active && (now_ms - spike_start_ms >= spike_ms)) {
        spike_active = false;
    }

    // 4) 计算基础目标力矩（阻尼）
    float target_torque = 0.0f;
    if (damping_engaged) {
        target_torque = -kp_damp * vel;
        if (target_torque >  maxTorque) target_torque =  maxTorque;
        if (target_torque < -maxTorque) target_torque = -maxTorque;
    } else {
        target_torque = 0.0f;
    }

    // 5) 脉冲叠加（若激活）
    if (spike_active) {
        // 脉冲方向总与速度反向
        float spike = - (vel >= 0.0f ? 1.0f : -1.0f) * spike_magnitude;
        // 安全限幅
        if (spike >  spike_max_limit) spike =  spike_max_limit;
        if (spike < -spike_max_limit) spike = -spike_max_limit;

        target_torque += spike;
        float hard_limit = max(spike_max_limit, maxTorque);
        if (target_torque >  hard_limit) target_torque =  hard_limit;
        if (target_torque < -hard_limit) target_torque = -hard_limit;
    }

    // 6) 预测性限幅：防止在下一个控制周期把速度翻转（从而产生反向补偿位移）
    static unsigned long last_ms = 0;
    float dt;
    if (last_ms == 0) dt = 0.001f; else dt = (now_ms - last_ms) * 0.001f;
    if (dt <= 0.0f) dt = 0.001f;

    // 估算将当前速度在 dt 内降为 0 需要的力矩（近似）
    // required_torque ≈ -vel * J / dt
    float torque_to_stop = -vel * J_est / dt;

    // 仅在 target_torque 会使速度翻转时限制到 torque_to_stop（保守限制）
    if (vel > 0.0f) {
        // target_torque 更负表示更强减速，若小于 torque_to_stop（更强），限制为 torque_to_stop
        if (target_torque < torque_to_stop) {
            target_torque = torque_to_stop;
        }
    } else if (vel < 0.0f) {
        if (target_torque > torque_to_stop) {
            target_torque = torque_to_stop;
        }
    }
    last_ms = now_ms;

    // 7) 力矩斜坡（slew）限制，防止输出瞬变
    float delta = target_torque - current_torque_out;
    if (delta >  torque_slew_rate) delta =  torque_slew_rate;
    if (delta < -torque_slew_rate) delta = -torque_slew_rate;
    current_torque_out += delta;

    // 8) 输出扭矩 —— 如果库函数名不同，请替换此行
    DFOC_M0_setTorque(current_torque_out); // <-- 替换为库中实际的 setTorque API

    // 9) 更新历史值
    prev_vel = vel;
}
