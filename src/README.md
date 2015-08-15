Author:YTC 
Mail:recessburton@gmail.com
Created Time: 2015.6.4

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>

Description：
	Telosb 上层模拟实现的ORW邻居关系建立过程接口.
	每个节点各自发送hello包，接收其它节点回复的ack包，计算“链路质量”，
	据此排序选择邻居加入邻居set.
	周期性地通过CTP向根节点发送节点的邻居集.
	直接使用接口命令startNei()开始工作.无事件触发
	
Logs：
	V 1.0 重新定义链路质量评估错误，修改了多个Bug.
	V 0.8 修正快速排序中的错误。
	V 0.7 邻居关系数据中加入温湿度光强数据。
	V 0.6 调整链路质量计算方法。
	V 0.5 修正邻居关系无法报告错误。
	V 0.4 增加链路评估条目至10条，加入邻居关系周期更新，更新周期为30s
	V 0.3 调整邻居信息结构体名称，减少冲突
	V 0.2 更正Bug #1,将根节点节点号默认设置成1
	V 0.1 完成基本功能
	
Known Bugs: 
	#1 节点不以根节点(0号节点)为邻居

