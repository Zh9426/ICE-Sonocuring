# 纯照射声场现象的文献对照（2026-11-13）

## 任务与范围

用户要求停止仿真，寻找已有论文对近场高压、活动孔径与目标外声场、焦点偏移的支持。本次只查阅公开文献和已有项目数据；没有启动MATLAB传播、VSX或硬件。用户提到“2 mm”，既有模拟设定为 **20 mm**，本文按20 mm讨论，2 mm不是此前设定的焦距。资料检索日期2026-11-13。

如“2 mm”指允许的峰值位置误差而非目标深度，52 μm工况下全64的目标盒内峰距20 mm为1.54 mm，48元为3.62 mm；奇偶32目标盒内峰距20 mm也是1.54 mm，但其全前向最高峰在近源侧方。不能据此认定任何版本满足临床或打印标准，须确认用户所说的2 mm含义和具体判据。

项目参考：`independent_simulation/docs/curing_four_variant_comparison_2026-11-12.md`、`independent_simulation/docs/curing_sparse_comparison_2026-11-13.md`。项目数据是线性、均匀、无损、无真实俯仰透镜的未标定单发模拟，不是实测或温升。

## 1. 焦点偏浅与孔径

Makov等，[Strong on-axis focal shift and its nonlinear variation in low-Fresnel-number ultrasound beams](https://doi.org/10.1121/1.2197805)，JASA 119, 3618–3624 (2006)，DOI 10.1121/1.2197805。论文报告低Fresnel数聚焦换能器即使在线性条件下，其轴向压力主峰也可从几何焦点向换能器偏移，并结合实验与数值分析电压上升后的非线性变化。支持“几何延时焦点与压力最大位置可以不同”，不验证本阵列的具体偏移值或原因。该工作不是同一ICE一维阵列；不能将圆形聚焦源公式直接当成本探头预测。

Ilham等，[Design and Optimization of Ultrasound Phased Arrays for Large-Scale Ultrasound Neuromodulation](https://pmc.ncbi.nlm.nih.gov/articles/PMC8904087/)，IEEE Transactions on Biomedical Circuits and Systems（2021）。作者制作另一种16元线阵并对12 mm焦距作了水听器测量；它的几何、频率和用途与本探头不同，但直接反驳“16元必然不能在较远目标聚焦”这种仅按数量判断的普遍结论，不能将其工作参数套用于本设备。

此前同样设置20 mm目标的 52 μm 模拟，在 z≥2 mm 前向区域，64/48/连续32/16元压力峰的深度分别约18.460/16.380/11.232/5.096 mm；32/16目标盒内最大值位于盒边界。奇偶32的目标盒内峰位于18.460 mm，但其全前向区域最高峰却在x≈±6.344、z≈2.028 mm，不能把目标盒峰误称全域峰。更大的连续孔径在这套设定中峰值更接近目标，但阵元数、孔径同时变化，不能推出“阵元越多就一定聚焦越远”。奇偶32与全64的目标盒峰深度相同，说明本组数据不支持用数量单独解释这一现象。

## 2. 孔径、稀疏度与目标外声场

Pajek & Hynynen，[The application of sparse arrays in high frequency transcranial focused ultrasound therapy: A simulation study](https://pmc.ncbi.nlm.nih.gov/articles/PMC3855063/)，Medical Physics 40, 122901 (2013)，DOI 10.1118/1.4829510。**模拟研究**使用1.5 MHz半球经颅阵列，降低阵元填充率后，在给定目标处焦斑尺寸平均变化不大，但目标外旁瓣/栅瓣可增强；在每元相同假设源压条件下目标声压大致随阵元数量变化。支持“较少阵元覆盖大跨度仍可形成较窄主瓣，同时目标外高值可能变强”的物理可能性；不直接验证6 MHz线阵、规则奇偶布局或人体内具体风险。

Wilcox & Zhang，[Quantification of the Effect of Array Element Pitch on Imaging Performance](https://pubmed.ncbi.nlm.nih.gov/29610090/)，IEEE TUFFC 65, 600–616 (2018)，DOI 10.1109/TUFFC.2018.2794627。**理论、数值与成像实验**研究一维周期阵列，指出间距、有限孔径、频带、方向和阵元指向性共同影响栅瓣；其成像实验不等同本任务单向发射声场。在假设声速1540 m/s、6 MHz时波长约0.257 mm，奇偶活动间距0.26 mm接近一波长，是研究宽角目标外分布的依据，并非本结果中某一个高值已被确认是栅瓣的证明。

Ellens等，[The utility of sparse 2D fully electronically steerable focused ultrasound phased arrays for thermal surgery: A simulation study](https://pure.johnshopkins.edu/en/publications/the-utility-of-sparse-2d-fully-electronically-steerable-focused-u-3/)，Physics in Medicine & Biology 56, 4913–4932 (2011)，DOI 10.1088/0031-9155/56/15/017。**声学加生物传热模拟**中，二维平面随机稀疏阵列的焦点形状可接近全阵列，但达到文中相同焦点热目标所需总功率更高，部分稀疏方案出现模型近场过热。该研究是500 kHz/1 MHz、厘米尺度和特定热消融目标；不能转用其功率倍率、温度或安全判断于本ICE探头。

本项目 z≥2 mm且排除目标盒的绝对压力峰为全64约2.4535、连续32约1.9276、奇/偶32约1.8090 assumed Pa。该“目标盒外”区域可能包含连续主瓣延伸，不能把它直接等同旁瓣；绝对值也不支持笼统声称“孔径越大，所有目标外声压越低”。在本模型中，奇偶组峰位于浅层离轴，且目标盒外峰相对目标盒峰约1.28；不同布局、归一化和区域划分会改变结论。目标盒峰处横向−6 dB剖面奇偶约0.716 mm、全64约0.715 mm，连续32约1.214 mm但属于目标盒边界剖面，且三个剖面不处于相同深度，不能将该数值当作同深度宽度验证。上述比较为单次模型输出而非实测精度。

## 3. 近场高压的证据与当前模型限制

Ellens论文支持“目标外近场可能受较强声场和吸收加热”的机制，但它的温度结果是其自身声热模拟，不能证明本研究探头会灼伤。Pajek论文也在其经颅模拟观察到部分稀疏工况目标外压力超过焦点，区域和条件与本模型不同。

实际声场表征方面，[Acoustic Field Characterization of Medical Array Transducers Based on Unfocused Transmits and Single-Plane Hydrophone Measurements](https://www.mdpi.com/1424-8220/19/4/863)，Sensors 19, 863 (2019)，以校准水听器测量阵列附近声场并比较传播重建和聚焦测量。它支持以水听器对近场和焦区做实测核验，不证明本阵列的奇偶近场峰值或幅度。

Goldstein、Gandhi与O’Brien，[Diffraction Effects in Hydrophone Measurements](https://www.brl.uiuc.edu/Publications/1998/Goldstein-UFFC-972-1998.pdf)，IEEE TUFFC 45, 972–979 (1998)，对未聚焦圆形活塞换能器进行水听器实验并分析轴向压力极大、极小及探头尺寸带来的空间平均。这为近场衍射起伏和测量分辨率提供实验依据，但其换能器和测量几何不同，不能直接证明本研究奇偶阵列的离轴高值。

本模型奇偶组源面Qp原生峰65→52 μm变化约+8.59%，超过5%内部诊断阈值；源面是数值声源平面，且不同压力峰和Qp峰的空间坐标不完全相同。不能将该源面数值当作已收敛、可直接对应实测的探头表面压力，更不能称为实测热量。域内最大压力、目标盒峰、目标点和目标外峰属于不同指标，比较时应分别写明。

## 可用于汇报的表述

“在固定20 mm几何延时目标、相同每阵元假设源信号的数值模型中，连续活动孔径改变时，前向压力峰位置和焦区分布发生变化；保持相近孔径跨度的奇偶32元组，目标附近横向主瓣与全64元相近，但近源及目标外分布明显不同。公开文献对有限孔径焦点偏移及稀疏阵列主瓣与目标外声场的权衡提供了定性支持。当前模型源面未充分网格收敛且未标定，具体幅度、近场高值机制及生物效应仍需验证。”
