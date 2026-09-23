# Acoustic field

实现位于 `../+ice/solve_pressure.m`。解析 Rayleigh 核采用矩形表面中点求积，有限尺寸阵元的方向性由积分自然产生。所有输入输出使用 SI；场数组按 `ndgrid(x,y,z)` 的 MATLAB 列主序组织。
