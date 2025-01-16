//例程3：阻尼-顺滑模式

// DengFOC V0.2
// 灯哥开源，遵循GNU协议，转载请著名版权！
// GNU开源协议（GNU General Public License, GPL）是一种自由软件许可协议，保障用户能够自由地使用、研究、分享和修改软件。
// 该协议的主要特点是，要求任何修改或衍生的作品必须以相同的方式公开发布，即必须开源。此外，该协议也要求在使用或分发软件时，必须保留版权信息和许可协议。GNU开源协议是自由软件基金会（FSF）制定和维护的一种协议，常用于GNU计划的软件和其他自由软件中。
// 仅在DengFOC官方硬件上测试过，欢迎硬件购买/支持作者，淘宝搜索店铺：灯哥开源
// 你的支持将是接下来做视频和持续开源的经费，灯哥在这里先谢谢大家了

#include "DengFOC.h"

int Sensor_DIR = 1;  // 传感器方向，若电机运动不正常，将此值取反
int Motor_PP = 7;    // 电机极对数
/******************************************************/
//0为阻尼模式
//1为顺滑模式
#define MODE 1

#define encoder1 4
#define encoder2 15
#define groundpin 14


/******************************************************/
//参数设置
float kp1 = 0.2;//阻尼模式P值
float kp2 = 0.0525;//顺滑模式P值
/******************************************************/
void setup() {
  Serial.begin(115200);
  pinMode(12, OUTPUT);
  digitalWrite(12, HIGH);  // 使能，一定要放在校准电机前

  DFOC_Vbus(12.6);  // 设定驱动器供电电压
  DFOC_alignSensor(Motor_PP, Sensor_DIR);



  pinMode(encoder1, OUTPUT);
  pinMode(encoder2, OUTPUT);
  pinMode(groundpin, OUTPUT);

  digitalWrite(encoder1, LOW); // 初始化 encoder1 为低电平
  digitalWrite(encoder2, LOW); // 初始化 encoder2 为低电平
  digitalWrite(groundpin, LOW); // 初始化 encoder2 为低电平


}


// 编码器设置
const int pulsesPerRevolution = 1; // 编码器每圈的脉冲数
float lastAngle = 0; // 上一次读取的角度

int pinA=0;
int pinB=0;


void loop() {
  runFOC();
  if(MODE == 0)
    Damp_Mode();
  else if(MODE == 1)
    Smooth_Mode();

  float currentAngle=DFOC_M0_Angle();
  // 计算角度增量
    float deltaAngle = currentAngle - lastAngle;

    // 转换为脉冲数
    int steps = int(deltaAngle * pulsesPerRevolution / 6.28);
      // 生成编码器信号
    if (steps != 0) {
      generateEncoderSignals(steps);
      lastAngle = currentAngle; // 更新上一次角度
    }
  

}

void Damp_Mode() {  //阻尼模式
    DFOC_M0_setTorque(kp1 * -1* DFOC_M0_Velocity());
}

void Smooth_Mode() {  //顺滑模式
   DFOC_M0_setTorque(kp2 * DFOC_M0_Velocity());
}

// 生成模拟编码器信号
void generateEncoderSignals(int steps) {
  bool direction = (steps > 0); // 方向：正向为 true，反向为 false
  steps = abs(steps);

  for (int i = 0; i < steps; i++) {
    // 根据方向生成 A 相和 B 相
    if (direction) {
      digitalWrite(encoder1, HIGH);
      delayMicroseconds(100); // 调整信号频率
      digitalWrite(encoder2, HIGH);
      delayMicroseconds(100);
      digitalWrite(encoder1, LOW);
      delayMicroseconds(100);
      digitalWrite(encoder2, LOW);
      delayMicroseconds(100);
    } else {
      digitalWrite(encoder2, HIGH);
      delayMicroseconds(100);
      digitalWrite(encoder1, HIGH);
      delayMicroseconds(100);
      digitalWrite(encoder2, LOW);
      delayMicroseconds(100);
      digitalWrite(encoder1, LOW);
      delayMicroseconds(100);
    }
  }
}
