

我想做大模型里beam search过程的可视化. 需要绘制矩形框图

定义每个token是一个单元正方形。
假设beam search 宽度是2

第一行是初始状态，一个较长的矩形，对应大模型的context

第二行在矩形框末尾添加两个正方形，颜色是橙色，虚线边框，表示上一步decoding产生的top2 token，为了方便下面引用，标记这两个token为 s0t0,s0t1

第三行把上一步的两个top2 token变成实线，颜色重置为白色，在此基础上 矩形框末尾再添加两个 token 表示上一步decoding产生的top2 token，为了方便下面引用，标记这两个token为 s1t0,s1t1, 同时在从s1t0,s1t1 各自引出弯曲箭头连线，随机指向s0t0,s0t1中的某一个。

接下来3行重复前一个步骤




上一种方法都是增量式地添加token到末端，beam search 还有另外一种方法 是每次把同一个beam的token组织在一块，更详细一点：


初始状体啊和第1步和前一种方法一样，

第2步是把生成的top2 token各自插入到自己的beam里，得到的token应该是 s0t0,s1t0,s0t1,s1t1， 其中s0t0,s1t0 组成一个beam, s0t1,s1t1组成一个beam， 两个beam颜色各不同。

后续的步骤都是把生成的token 插入到各自的beam。这样就不需要箭头来指明祖先关系了


但是需要注意的是

