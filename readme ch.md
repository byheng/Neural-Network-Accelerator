# Open Source Accelerator on FPGA
**切换语言: [英语](README.md), [中文](README_zh.md)**
**开发日志: [英语](DevLog.md), [中文](DevLog_zh.md)**

该项目旨在实现卷积神经网络的加速电路。项目以yolov8为实现对象，目标是完成一个包含卷积、残差和、上采样、池化、concat等算子操作的加速电路。由于整体电路设计思想是高效复用和指令化调用，因此除了部署yolov8网络外，由上述算子操作组成的其他神经网络也可以编译到加速器上。

# 可实现算子

| 算子名称       | 描述 |
| :-----------: | :-----------: |
| 卷积      | 3*3的卷积操作，步幅为1或2， 和padding为任意。可以选择是否激活（由参数指令动态控制）。       |
| 残差和   | 两个特征块的残差和。        |
| 上采样 | 对特征图进行2倍上采样。仅支持nearest模式 |
| 池化 | 对特征图做最大值池化，支持步幅为1或者2。 |
| 拼接 | 拼接操作（concat）不通过硬件电路实现，而是在内存分配的过程中实现。 |

# 仿真结果

加速器的仿真时钟是100Mhz，yolov8n的单帧推理时间是113ms。
![image](./fig/simulation_result.png)

# 部署到xilinx 19EG上

加速器的硬件部署时钟为200MHz，Yolov8n单帧推理时间为60ms，后处理时间为50ms。推理和后处理是并行进行的，因此总帧速率可以达到18-19fps。 

<video src="./fig/result video.mp4" autoplay="true" controls="controls" width="1280" height="720">
</video>

# 我的频道

B站: https://www.bilibili.com/video/BV1YBwdeGEQL/?spm_id_from=333.1387.homepage.video_card.click&vd_source=adcb6ca5248fa9aa53c8041deee6707b

## 引用
- [yolov8-prune-network](https://github.com/ybai789/yolov8-prune-network-slimming)