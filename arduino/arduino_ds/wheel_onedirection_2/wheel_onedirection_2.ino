#include "DengFOC.h"

// ================= 硬件参数 =================
int Sensor_DIR = 1;          // 传感器方向
int Motor_PP   = 6;          // 电机极对数
const int ENABLE_PIN = 12;   // 使能引脚

// ================= 阻尼参数 =================
float kp_damp    = 2.2f;     // 阻尼增益（主阻尼）
float kv_viscous = 0.8f;     // 额外黏性阻尼（抑制持续外力震动）
float maxTorque  = 5.5f;     // 力矩限幅
bool  damp_on_cw = true;     // true=顺时针阻尼，false=逆时针

// ================= 迟滞与稳定参数 =================
float vel_on_threshold  = 0.20f;   // 进入阻尼阈值
float vel_off_threshold = 0.10f;   // 退出阻尼阈值
float vel_deadband      = 0.02f;   // 零速死区（防抖、防回转）
float torque_slew_rate  = 0.04f;   // 力矩变化速率（越小越稳）

// ================= 滤波与预测 =================
float vel_lpf_alpha = 0.25f;  // 速度一阶低通
float J_est = 0.02f;          // 转动惯量估计（越大越不回转，偏保守）

// ================= 内部状态 =================
float current_torque_out = 0.0f;
bool  damping_engaged    = false;
float vel_filt           = 0.0f;
unsigned long last_ms    = 0;

// =================================================
void setup() {
  pinMode(ENABLE_PIN, OUTPUT);
  digitalWrite(ENABLE_PIN, HIGH);

  DFOC_Vbus(12.6);
  DFOC_alignSensor(Motor_PP, Sensor_DIR);
}

void loop() {
  runFOC();
  SingleDirDamp_Mode();
}

// =================================================
// 单向阻尼模式（稳定 + 无回转版）
// =================================================
void SingleDirDamp_Mode() {

    unsigned long now_ms = millis();

    // -------- 读取并滤波速度 --------
    float vel = DFOC_M0_Velocity();
    vel_filt = vel_filt * (1.0f - vel_lpf_alpha) + vel * vel_lpf_alpha;
    float absvel = fabs(vel_filt);

    // -------- 零速死区：彻底防止回转 --------
    if (absvel < vel_deadband) {
        // 平滑回零
        float delta0 = -current_torque_out;
        if (delta0 >  torque_slew_rate) delta0 =  torque_slew_rate;
        if (delta0 < -torque_slew_rate) delta0 = -torque_slew_rate;
        current_torque_out += delta0;
        DFOC_M0_setTorque(current_torque_out);
        return;
    }

    // -------- 判断是否需要阻尼 --------
    bool isCW = (vel_filt > 0.0f);
    bool want_damp_direction =
        (damp_on_cw && isCW) || (!damp_on_cw && !isCW);

    if (want_damp_direction) {
        if (!damping_engaged && absvel >= vel_on_threshold)
            damping_engaged = true;
        else if (damping_engaged && absvel <= vel_off_threshold)
            damping_engaged = false;
    } else {
        damping_engaged = false;
    }

    // -------- 计算基础目标力矩（纯速度阻尼） --------
    float target_torque = 0.0f;

    if (damping_engaged) {
        // 主阻尼 + 黏性阻尼
        target_torque = -(kp_damp + kv_viscous) * vel_filt;

        // 限幅
        if (target_torque >  maxTorque) target_torque =  maxTorque;
        if (target_torque < -maxTorque) target_torque = -maxTorque;
    } else {
        target_torque = 0.0f;
    }

    // ===== 预测性限幅：防止“刹过头”导致回转 =====
    float dt = 0.001f;
    if (last_ms != 0)
        dt = max(0.001f, (now_ms - last_ms) * 0.001f);
    last_ms = now_ms;

    // 估计在 dt 内刚好把速度降到 0 的最大允许制动力矩
    float torque_to_stop = -vel_filt * J_est / dt;

    if (vel_filt > 0.0f) {
        if (target_torque < torque_to_stop)
            target_torque = torque_to_stop;
    } else {
        if (target_torque > torque_to_stop)
            target_torque = torque_to_stop;
    }

    // -------- 绝对安全保护：不允许“推着转” --------
    if (vel_filt > 0.0f && target_torque > 0.0f) target_torque = 0.0f;
    if (vel_filt < 0.0f && target_torque < 0.0f) target_torque = 0.0f;

    // -------- 力矩斜坡（最终稳定关键） --------
    float delta = target_torque - current_torque_out;
    if (delta >  torque_slew_rate) delta =  torque_slew_rate;
    if (delta < -torque_slew_rate) delta = -torque_slew_rate;
    current_torque_out += delta;

    // -------- 输出 --------
    DFOC_M0_setTorque(current_torque_out);
}
