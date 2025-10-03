// 例程3：阻尼-顺滑模式（A/B 两相增量编码器仿真 - 状态机版）

// DengFOC V0.2
// 灯哥开源，遵循GNU协议，转载请著名版权！
// 仅在DengFOC官方硬件上测试过

#include "DengFOC.h"
#include <math.h>  // lroundf

//================= 你的原始参数 =================//
int Sensor_DIR = 1;   // 传感器方向，若电机运动不正常，将此值取反
int Motor_PP   = 7;   // 电机极对数

// 0 为阻尼模式；1 为顺滑模式
#define MODE 1

// A/B 两相输出引脚（可改）
#define encoder1 4   // A 相
#define encoder2 15  // B 相
#define groundpin 14 // 对外地参考（可选接）

// 阻尼、顺滑模式增益
float kp1 = 0.2f;   // 阻尼模式 P 值（建议 > 0）
float kp2 = 0.04f; // 顺滑模式 P 值（建议与阻尼同号，见下方 Smooth_Mode 实现）

//================= 增量编码器仿真参数 =================//
// 目标 CPR（每圈 A 相“黑白条”个数，四倍频后边沿数 = 4*CPR）
const long CPR = 1024;                 // 想改分辨率时只改这个
const float _2PI = 6.28318530718f;
const float EDGES_PER_REV = 4.0f * CPR;
const float ANGLE_PER_EDGE = _2PI / EDGES_PER_REV; // 每个“边沿”对应的机械角(rad)

// A/B 相序：若想交换领先关系，把这个表的顺序改为 00->01->11->10->00 即可
static inline uint8_t edgeToAB(long e) {
  switch (e & 0x3) {          // 00 -> 10 -> 11 -> 01 -> 00
    case 0: return 0b00;
    case 1: return 0b10;
    case 2: return 0b11;
    default:return 0b01;
  }
}

//================= 运行时状态 =================//
volatile long edge_prev = 0;     // 已经输出到的“边沿索引”
uint8_t ab_state = 0;            // 当前 AB 状态（00/01/11/10）
float angle_unwrapped = 0.0f;    // 连续角（含圈数）
float last_position   = 0.0f;    // 上一帧单圈角（0..2π）
float current_position= 0.0f;    // 当前单圈角（0..2π）

//================= 函数声明 =================//
void Damp_Mode();   // 阻尼模式
void Smooth_Mode(); // 顺滑模式（实现为小阻尼，见下）


//================= Arduino 生命周期 =================//
void setup() {
  Serial.begin(115200);

  pinMode(12, OUTPUT);
  digitalWrite(12, HIGH);  // 驱动使能（校准前务必先使能）

  DFOC_Vbus(12.6);                          // 设定驱动器供电电压
  DFOC_alignSensor(Motor_PP, Sensor_DIR);   // 传感器/极对数校准

  // A/B 两相输出引脚
  pinMode(encoder1, OUTPUT);
  pinMode(encoder2, OUTPUT);
  pinMode(groundpin, OUTPUT);

  digitalWrite(encoder1, LOW);
  digitalWrite(encoder2, LOW);
  digitalWrite(groundpin, LOW); // 对外参考地（可接）

  // 初始化角度（单圈角到连续角）
  float a = DFOC_M0_Angle(); // 0..2π
  last_position   = a;
  angle_unwrapped = a;
}

void loop() {
  // —— 你的 FOC 主循环 —— //
  runFOC();
  if (MODE == 0)      Damp_Mode();
  else if (MODE == 1) Smooth_Mode();

  // 读取当前机械角（0..2π），展开成连续角（考虑跨越边界）
  current_position = DFOC_M0_Angle();
  float d = current_position - last_position;
  if (d >  3.1415926f) d -= _2PI; // 最近原则展开
  if (d < -3.1415926f) d += _2PI;
  angle_unwrapped += d;
  last_position = current_position;

  // —— 相位状态机：对称取整 + 多步补偿 —— //
  // 1) 将当前连续角换算为“应到达的边沿索引”（对称四舍五入，正反一致）
  long edge_now = (long)lroundf(angle_unwrapped / ANGLE_PER_EDGE);

  // 2) 逐步推进到目标索引：即使一帧跨多边沿，也逐个补齐（不漏计数）
  while (edge_prev != edge_now) {
    edge_prev += (edge_now > edge_prev) ? 1 : -1;

    uint8_t newAB = edgeToAB(edge_prev);
    if (newAB != ab_state) {
      // A = bit1, B = bit0
      digitalWrite(encoder1, (newAB >> 1) & 1);
      digitalWrite(encoder2,  newAB       & 1);
      ab_state = newAB;
    }
  }

  // // —— 建议：把串口打印限频，否则会打乱时序 —— //
  // static uint32_t t = 0;
  // if (millis() - t >= 50) {    // 每 50ms 打一次
  //   t = millis();
  //   // 查看 A/B 电平（可注释掉）
  //   Serial.printf("%d,%d\n", digitalRead(encoder1), digitalRead(encoder2));
  // }
}


//================= 力矩模式实现 =================//
// 阻尼模式：对速度施加“正阻尼”（稳定）
void Damp_Mode() {  
  DFOC_M0_setTorque(-kp1 * DFOC_M0_Velocity());
}

// 顺滑模式：建议也用“正阻尼”，但增益更小（更“顺滑”）
// 若你确实想要“推着走”的手感，可改成 +kp2，但注意那是正反馈（负阻尼），容易发飘。
void Smooth_Mode() {  
  DFOC_M0_setTorque(kp2 * DFOC_M0_Velocity());
}
