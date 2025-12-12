// ----------------- 新增全局状态与参数 -----------------
float spike_magnitude     = 8.0f;     // 脉冲力矩幅度（正数，单位同 maxTorque），会被 clamp 到 spike_max_limit
float spike_max_limit     = 12.0f;    // 脉冲允许的最大绝对力矩（安全上限）
unsigned long spike_ms    = 50;       // 脉冲持续时间（毫秒），可调小到 20~100ms 试验
unsigned long last_time_us = 0;       // 用于计算 dt
float prev_vel = 0.0f;               // 用于检测符号变化 / 估计加速度

bool  spike_active = false;
unsigned long spike_start_ms = 0;
// ------------------------------------------------------

void SingleDirDamp_Mode() {
    // 时间（毫秒）
    unsigned long now_ms = millis();

    // 读取速度（库函数）
    float vel = DFOC_M0_Velocity();   // 当前速度
    bool isCW = (vel > 0.0f);
    bool want_damp_direction = (damp_on_cw && isCW) || (!damp_on_cw && !isCW);
    float absvel = fabs(vel);

    // 迟滞逻辑（保留你原先的）
    if (want_damp_direction) {
        if (!damping_engaged && absvel >= vel_on_threshold) {
            damping_engaged = true;
        } else if (damping_engaged && absvel <= vel_off_threshold) {
            damping_engaged = false;
        }
    } else {
        damping_engaged = false;
    }

    // --------- 检测“向阻尼侧转动的一瞬间”触发脉冲 ----------
    // 条件1：速度符号由非目标方向变为目标方向（例如从负变为正）
    bool sign_changed_to_target = false;
    if (damp_on_cw) {
        if (prev_vel <= 0.0f && vel > 0.0f) sign_changed_to_target = true;
    } else {
        if (prev_vel >= 0.0f && vel < 0.0f) sign_changed_to_target = true;
    }

    // 条件2：或由未进入阻尼态到马上进入阻尼态（原来没有阻尼，现在达到 on 阈值）
    bool just_engaged_by_threshold = false;
    if (want_damp_direction && !spike_active) {
        if (!damping_engaged && absvel >= vel_on_threshold) {
            // 注意：damping_engaged 会在上面被置 true —— 但我们在这里也认为这是触发点之一
            just_engaged_by_threshold = true;
        }
    }

    // 如果任一触发条件成立，则开启脉冲
    if ((sign_changed_to_target || just_engaged_by_threshold) && !spike_active) {
        spike_active = true;
        spike_start_ms = now_ms;
    }

    // 如果脉冲到期，关闭它
    if (spike_active && (now_ms - spike_start_ms >= spike_ms)) {
        spike_active = false;
    }
    // -----------------------------------------------------------

    // 计算目标力矩（基础阻尼）
    float target_torque = 0.0f;
    if (damping_engaged) {
        target_torque = -kp_damp * vel;   // 阻尼：与速度反向
        // 限幅（基础）
        if (target_torque >  maxTorque) target_torque =  maxTorque;
        if (target_torque < -maxTorque) target_torque = -maxTorque;
    } else {
        target_torque = 0.0f;
    }

    // 如果脉冲激活，则在 target_torque 上叠加瞬时脉冲（方向与阻尼方向相同：总是与速度反向）
    if (spike_active) {
        float spike = - (vel >= 0.0f ? 1.0f : -1.0f) * spike_magnitude; // 与速度方向相反
        // 脉冲安全限幅：不超过 spike_max_limit
        if (spike >  spike_max_limit) spike =  spike_max_limit;
        if (spike < -spike_max_limit) spike = -spike_max_limit;

        // 将 spike 与基础 target 合并（注意：这里是叠加），再 clamp 到硬件允许的总力矩范围
        target_torque += spike;

        // 总体硬限幅（如果希望脉冲可以超越 normal maxTorque，可把上面 maxTorque 改为 pulse_limit）
        float hard_limit = max(spike_max_limit, maxTorque); // 允许取较大值
        if (target_torque >  hard_limit) target_torque =  hard_limit;
        if (target_torque < -hard_limit) target_torque = -hard_limit;
    }

    // 力矩斜坡（slew）限制，防止瞬变（保留你的逻辑）
    float delta = target_torque - current_torque_out;
    if (delta >  torque_slew_rate) delta =  torque_slew_rate;
    if (delta < -torque_slew_rate) delta = -torque_slew_rate;
    current_torque_out += delta;

    // 最终输出
    DFOC_M0_setTorque(current_torque_out);

    // 更新 prev_vel
    prev_vel = vel;
}
