//DengFOC V0.2
//灯哥开源，遵循GNU协议，转载请著名版权！
//GNU开源协议（GNU General Public License, GPL）是一种自由软件许可协议，保障用户能够自由地使用、研究、分享和修改软件。
//该协议的主要特点是，要求任何修改或衍生的作品必须以相同的方式公开发布，即必须开源。此外，该协议也要求在使用或分发软件时，必须保留版权信息和许可协议。GNU开源协议是自由软件基金会（FSF）制定和维护的一种协议，常用于GNU计划的软件和其他自由软件中。
//仅在DengFOC官方硬件上测试过，欢迎硬件购买/支持作者，淘宝搜索店铺：灯哥开源
//你的支持将是接下来做视频和持续开源的经费，灯哥在这里先谢谢大家了

#include "DengFOC.h"

int Sensor_DIR = 1;  //传感器方向
int Motor_PP = 7;     //电机极对数

#define trigger 4

// #define encoder0PinA 4        // sensor A of rotary encoder
// #define encoder0PinB 15        // sensor B of rotary encoder

// variables for rotary encoder
volatile signed int wheelDirection = 0;    // variable for counting ticks of rotary encoder



void setup() {
  Serial.begin(115200);
  pinMode(12, OUTPUT);
  digitalWrite(12, HIGH);  //V4电机使能

  DFOC_Vbus(12.6);  //设定驱动器供电电压
  DFOC_alignSensor(Motor_PP, Sensor_DIR);

    
  pinMode(trigger, INPUT_PULLUP);
    
   

  // interrupt for rotary encoder
  // attachInterrupt(digitalPinToInterrupt(encoder0PinA), wheelMoved, FALLING);

}

int count = 0;
float CountAngel=0;

void loop() {
  runFOC();

  // // 力位（加入电流环后）
  // DFOC_M0_SET_ANGLE_PID(0.5,0,0.003,100000,0.1);
  // DFOC_M0_SET_CURRENT_PID(1.25,50,0,100000);
  // DFOC_M0_set_Force_Angle(serial_motor_target());

  // //速度（加入电流环后）
  // DFOC_M0_SET_VEL_PID(3,2,0,100000,0.1);
  // DFOC_M0_SET_CURRENT_PID(0.5,50,0,100000);
  // DFOC_M0_setVelocity(serial_motor_target());

  //位置-速度-力（加入电流环后）
  DFOC_M0_SET_ANGLE_PID(1, 0, 0, 100000, 30);
  DFOC_M0_SET_VEL_PID(0.02, 1, 0, 100000, 0.2);
  DFOC_M0_SET_CURRENT_PID(5, 200, 0, 100000);

  int TriggerState = digitalRead(trigger); // 读取引脚状态

 
  DFOC_M0_set_Velocity_Angle(DFOC_M0_Angle());


  //电流力矩
  // DFOC_M0_SET_CURRENT_PID(5,200,0,100000);
  // DFOC_M0_setTorque(serial_motor_target());

  count++;
  if (count > 100) {
    count = 0;
    //Serial.printf("%f\n", DFOC_M0_Current());
    Serial.printf("%f,%f,%d,%d\n", DFOC_M0_Current(), DFOC_M0_Velocity(),CountAngel,TriggerState);
  }
  //接收串口
  serialReceiveUserCommand();
}



// // Wheel moved: on encoder A change, check encoder B state and send 1=CW / -1=CCW accordingly
// void wheelMoved() {
//     if (digitalRead(encoder0PinB)==LOW) {
//       wheelDirection = 1;
      
//     }
//     else {
//       wheelDirection = -1;
//     }
//     CountAngel +=wheelDirection;

//     // Serial.print(wheelDirection);
//     // Serial.print("\n");
// }