#include "DengFOC.h"

// ---------------- 原始硬件 & 阻尼参数（确认与你原来的一致） ----------------
int Sensor_DIR = 1;
int Motor_PP   = 6;
const int ENABLE_PIN = 12;

float kp_damp    = 2.2f;
float maxTorque  = 5.5f;
bool  damp_on_cw = true;

// 迟滞与斜坡参数（防抖动）
float vel_on_threshold  = 0.2f;
float vel_off_threshold = 0.1f;
float torque_slew_rate  = 0.05f;

// 内部状态（确保为全局）
float current_torque_out = 0.0f;
bool  damping_engaged = false;

// ---------------- 新增脉冲相关全局参数 ----------------
float spike_magnitude     = 8.0f;     // 脉冲幅度（正数）
float spike_max_limit     = 12.0f;    // 脉冲最大允许绝对力矩
unsigned long spike_ms    = 50;       // 脉冲持续时间（ms）
float prev_vel = 0.0f;

bool  spike_active = false;
unsigned long spike_start_ms = 0;
// ------------------------------------------------------

void setup() {
  pinMode(ENABLE_PIN, OUTPUT);
  digitalWrite(ENABLE_PIN, HIGH);    // 使能驱动

  DFOC_Vbus(12.6);
  DFOC_alignSensor(Motor_PP, Sensor_DIR);
}

void loop() {
  runFOC();
  SingleDirDamp_Mode();
}

// ------------------ 重要：如果你现在编译报错 “DFOC_M0_Velocity” 或 “DFOC_M0_setTorque” 未声明 ---------------
// 暂时性的**编译存根**（用于验证其它逻辑是否能通过编译/仿真）。**仅在你还没找到真实 API 时临时启用**：
// 把下面两行中的任何一个取消注释可以临时避免编译错误（但是不会读到真实速度或驱动真实电机）。
// float DFOC_M0_Velocity() { return 0.0f; }        // <-- 临时返回 0 的 velocity 存根（用于测试编译）
// void  DFOC_M0_setTorque(float t) { /* stub: 不做任何事 */ } // <-- 临时存根，不输出扭矩
// -----------------------------------------------------------------------------------------------------------------

void SingleDirDamp_Mode() {
    unsigned long now_ms = millis();

    // --- 读取速度：这里使用库提供的函数名。若编译提示未声明，
    //     请打开 DengFOC.h / 库源码，确认正确的 API 名称并替换下面这一行 ----
    float vel = DFOC_M0_Velocity();   // <-- 若此行报错：请替换为库中实际的读速率函数名
    // 例如可能是 DFOC_getVelocity(), DFOC.M0.getVelocity(), Sensor_getVelocity(), 等等

    bool isCW = (vel > 0.0f);
    bool want_damp_direction = (damp_on_cw && isCW) || (!damp_on_cw && !isCW);
    float absvel = fabs(vel);

    // 迟滞逻辑
    if (want_damp_direction) {
        if (!damping_engaged && absvel >= vel_on_threshold) {
            damping_engaged = true;
        } else if (damping_engaged && absvel <= vel_off_threshold) {
            damping_engaged = false;
        }
    } else {
        damping_engaged = false;
    }

    // 检测方向切换或通过 on 阈值触发脉冲
    bool sign_changed_to_target = false;
    if (damp_on_cw) {
        if (prev_vel <= 0.0f && vel > 0.0f) sign_changed_to_target = true;
    } else {
        if (prev_vel >= 0.0f && vel < 0.0f) sign_changed_to_target = true;
    }

    bool just_engaged_by_threshold = false;
    if (want_damp_direction && !spike_active) {
        // 注意：damping_engaged 在上面已经被更新，所以这里用 absvel 与阈值判断触发
        if (absvel >= vel_on_threshold && prev_vel != vel) {
            just_engaged_by_threshold = true;
        }
    }

    if ((sign_changed_to_target || just_engaged_by_threshold) && !spike_active) {
        spike_active = true;
        spike_start_ms = now_ms;
    }

    if (spike_active && (now_ms - spike_start_ms >= spike_ms)) {
        spike_active = false;
    }

    // 计算目标力矩（基础阻尼）
    float target_torque = 0.0f;
    if (damping_engaged) {
        target_torque = -kp_damp * vel;
        if (target_torque >  maxTorque) target_torque =  maxTorque;
        if (target_torque < -maxTorque) target_torque = -maxTorque;
    } else {
        target_torque = 0.0f;
    }

    // 脉冲叠加（如果激活）
    if (spike_active) {
        float spike = - (vel >= 0.0f ? 1.0f : -1.0f) * spike_magnitude;
        if (spike >  spike_max_limit) spike =  spike_max_limit;
        if (spike < -spike_max_limit) spike = -spike_max_limit;

        target_torque += spike;
        float hard_limit = max(spike_max_limit, maxTorque);
        if (target_torque >  hard_limit) target_torque =  hard_limit;
        if (target_torque < -hard_limit) target_torque = -hard_limit;
    }

    // 力矩斜坡限制
    float delta = target_torque - current_torque_out;
    if (delta >  torque_slew_rate) delta =  torque_slew_rate;
    if (delta < -torque_slew_rate) delta = -torque_slew_rate;
    current_torque_out += delta;

    // ---- 输出扭矩：同样，若 DFOC_M0_setTorque 未声明，请在库中查找正确的输出 API ----
    DFOC_M0_setTorque(current_torque_out); // <-- 若此处报错，请替换为库中实际的 setTorque 函数名

    prev_vel = vel;
}
