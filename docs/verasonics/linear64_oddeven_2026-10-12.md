# 2026-10-12：64阵元奇偶交替成像与候选固化驱动

## 本轮已实现

按用户最新确认，将当前默认从左右连续32/32改为奇偶交替32/32。入口为[SetUpICE_ImagingCuring.m](../../verasonics/dual_mode/SetUpICE_ImagingCuring.m)，配置为[default_config.m](../../verasonics/dual_mode/+icevs/default_config.m)，完整运行方式见[README](../../verasonics/dual_mode/README.md)。

|用途|默认物理阵元序号|行为|
|---|---|---|
|成像|1,3,5,…,63|15角平面波TX及同组RX，二维XZ重建|
|候选固化照射|2,4,6,…,64|按目标点计算聚焦延时，有限脉冲，rcv=0|

编号按ElementPos的x坐标从小到大排列，默认等于逻辑行号。ConnectorES独立映射到连接器信号；即使列表重排或接线倒序，也不以连接器奇偶重新划组。用户确认奇偶交替；奇数成像是本版assumed角色约定，可设置`cfg.partition.layout='even_imaging_odd_exposure'`互换。

保存文件仍含64项向量，未参与发射的阵元Apod和Delay为0。时间顺序为成像/重建→候选固化发射→再充电及接收恢复等待→下一轮，末尾stop。波形、电压、PRI、轮数及unknown限值沿用既有默认，未依据孔径变大提高驱动强度。人工unfreeze可能重启有限会话。

## 几何及计算口径

|项目|本版数值|来源/解释|
|---|---|---|
|物理阵元数|64|用户确认与原始工作代码相符|
|物理pitch / width|0.13 / 0.11 mm|existing_code，未标定|
|每组活动阵元数|32|奇偶分区定义|
|每组相邻活动中心间距|0.26 mm|2×源码pitch；显式非均匀坐标时不能套用|
|每组孔径跨度|8.17 mm|31×0.26+0.11，包含间隙|
|成像/照射组中心x|−0.065 / +0.065 mm|默认源码几何平均值|
|声速|1540 m/s|assumed|
|成像/照射频率|6 / 6 MHz|沿用配置，未校准实际输出|
|成像/照射电压请求|5 / 5 V，Profile1|assumed，非额定或安全工作推荐|
|候选照射|20周期、PRI 1000 us、10脉冲/焦点、30轮|assumed离线示例|

求解器范围是几何传播路程/声速的解析发射延时、vendor数学工具对照和事件编译，没有进行声场传播、PSF、温升或材料反应求解。TX.Delay以Trans.frequency周期表示，时间以us报告。有效孔径跨度大于原左右组，但不是连续满孔径；奇偶稀疏采样对栅瓣、旁瓣和目标外暴露的影响仍未验证。不得由跨度或事件通过推出声压增益、成像改善或成功固化。

## 手册依据

本轮直接读取用户指定目录的四份PDF原件，版本如下；所列页码为页内印刷页码。

- Sequence Programming Manual，D00163 Rev. K，§4.3.2第24–25页：TX波形、Apod选择与禁用阵元；§13.1第107、110–111页：type0几何、ElementPos索引到ConnectorES映射及connType。本轮实现按阵元索引保留完整向量，映射不被分区重写。
- Product Specification，D00108 Rev. L，§1.3.1第7页：UTA与系统配置兼容表。沿用源码connType=4不能代替实际UTA/系统兼容性确认。
- User Manual，D00107 Rev. K，§4.4.1–4.4.2第30页：Profile1–4与Profile5的电源用途及选件区别。未确认实际Profile5配置，不在本版强制开启。
- Initial Setup Instructions，D00109 Rev. D，§4.5第9页：系统自检与日志路径。本轮未执行激活、自检或硬件操作。

## 实际验证与交付

MATLAB R2024b Update 2：相关43/43测试通过，19份MATLAB文件Code Analyzer 0消息。新增测试先在旧实现上得到4项失败/1项通过，再在奇偶实现上5/5通过；失败包括原左右掩码/中心不符、反向角色未支持和输出前缀不符。既有左右分区与synthetic矩阵通过显式fixture保留回归。

- [新增测试](../../tests/test_verasonics_oddeven.m)、[全部驱动测试结果](../../results/verasonics_linear64_oddeven/test_results.csv)、[先行失败记录](../../results/verasonics_linear64_oddeven/tdd_red_test_results.csv)。
- [三模式生成脚本](../../scripts/verify_verasonics_dual_mode.m)、[模式表](../../results/verasonics_linear64_oddeven/mode_summary.csv)、[静态检查](../../results/verasonics_linear64_oddeven/code_analysis.json)。
- [交替模式阵元表](../../results/verasonics_linear64_oddeven/ICE_Linear64OddEven_interleaved_elements.csv)、[逐事件表](../../results/verasonics_linear64_oddeven/ICE_Linear64OddEven_interleaved_events.csv)、[分区图](../../results/verasonics_linear64_oddeven/physical_partition.png)。
- [验证汇总](../../results/verasonics_linear64_oddeven/validation.json)、[原始源码完整性复核](../../results/verasonics_linear64_oddeven/vendor_integrity.json)。

默认交替模式933事件、450次成像采集、300次候选照射，调度时间下界1,235,264 us；时间由名义事件等待和传播时长推算，不是实测时长或帧率。公共RF缓冲预留900 MiB，非实测内存占用。新目录与前缀避免覆盖历史左右结果；保存的MAT含ICEConfig和ICEReport，JSON schema为4。

尚未执行VSX加载/仿真、实物发射/采集、水听器声场、头端温升或固化实验；本轮也未重新运行全仓库仿真测试。硬件额定burst、duty、电压及热负荷等仍unknown，simulate_mode=0继续被拒绝，hardware_qualified=false。
