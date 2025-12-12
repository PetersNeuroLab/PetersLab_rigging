#include "DengFOC.h"

// -------- 硬件参数 --------
int Sensor_DIR = 1;          // 传感器方向，方向不对时改为 -1
int Motor_PP   = 6;          // 电机极对数
const int ENABLE_PIN = 12;   // 使能引脚

// -------- 阻尼参数 --------
float kp_damp    = 0.8f;     // 阻尼增益（正数）
float maxTorque  = 9.0f;     // 力矩限幅（确认单位/范围后调整）
bool  damp_on_cw = true;     // true = 顺时针阻尼；false = 逆时针阻尼
// --------------------------

// ------ 迟滞与斜坡参数（用于防抖动） -------
float vel_on_threshold  = 0.2f;   // 进入阻尼阈值（调整到高于速度噪声）
float vel_off_threshold = 0.1f;  // 退出阻尼阈值（比 on 小，形成迟滞）
float torque_slew_rate  = 0.05f;   // 每次循环最大允许变化的力矩（绝对值）
// 内部状态
float current_torque_out = 0.0f;
bool  damping_engaged = false;
// ----------------------------------------------

void setup() {
  pinMode(ENABLE_PIN, OUTPUT);
  digitalWrite(ENABLE_PIN, HIGH);    // 使能驱动

  DFOC_Vbus(12.6);                    // 设定驱动器供电电压
  DFOC_alignSensor(Motor_PP, Sensor_DIR);
}

void loop() {
  runFOC();
  SingleDirDamp_Mode();
}

// -------- 单向阻尼模式（无滤波、无串口、带迟滞与力矩斜坡） --------
void SingleDirDamp_Mode() {
    // 读取速度（你确认库里有 DFOC_M0_Velocity）
    float vel = DFOC_M0_Velocity();   // 当前速度

    // 假设 vel > 0 表示顺时针（CW）
    bool isCW = (vel > 0.0f);

    // 仅在目标方向考虑阻尼
    bool want_damp_direction = (damp_on_cw && isCW) || (!damp_on_cw && !isCW);

    // 迟滞逻辑防止零点抖动
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

    // 计算目标力矩（但不直接输出）
    float target_torque = 0.0f;
    if (damping_engaged) {
        target_torque = -kp_damp * vel;   // 阻尼：与速度反向
        // 限幅（注意单位/范围）
        if (target_torque >  maxTorque) target_torque =  maxTorque;
        if (target_torque < -maxTorque) target_torque = -maxTorque;
    } else {
        target_torque = 0.0f;
    }

    // 力矩斜坡（slew）限制，防止瞬变
    float delta = target_torque - current_torque_out;
    if (delta >  torque_slew_rate) delta =  torque_slew_rate;
    if (delta < -torque_slew_rate) delta = -torque_slew_rate;
    current_torque_out += delta;

    // 最终输出
    DFOC_M0_setTorque(current_torque_out);
}
