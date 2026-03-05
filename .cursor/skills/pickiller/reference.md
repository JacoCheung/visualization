# Pickiller 调参参考

## Potrace 参数

| 参数 | 含义 | 默认值 | 推荐范围 | 效果 |
|------|------|--------|----------|------|
| `--alphamax` | 拐角平滑度（0 = 锐角，1.34 = 最平滑） | 1.0 | 0.5 – 1.34 | 值越小保留越多尖角；手写体用 0.6–0.8，几何图用 1.0–1.2 |
| `--turdsize` | 消除面积小于 N 像素的斑点 | 2 | 2 – 30 | 增大可去噪但会丢细节（文字笔画）；照片扫描建议 10–20 |
| `--opttolerance` | 曲线优化容差 | 0.2 | 0.1 – 0.5 | 值越小路径越精确（文件越大）；值越大越平滑 |
| `--turnpolicy` | 路径走向策略 | `minority` | `black` / `white` / `minority` / `majority` | 处理黑白交界歧义时的取舍；一般用默认 `minority` |
| `--longcurve` | 启用长曲线优化 | off | — | 对大面积平滑区域可减少节点数 |
| `--unit` | SVG 单位缩放（DPI） | 10 | 1 – 72 | 控制输出 SVG 的尺寸；如需 1:1 像素映射用 1 |

## ImageMagick 预处理技巧

### 基础灰度 + 二值化

```bash
magick input.png -colorspace Gray -normalize -threshold 50% output.pbm
```

`-normalize` 拉伸直方图到全范围，改善对比度。

### 自适应阈值（光照不均时）

```bash
magick input.png -colorspace Gray -lat 25x25+10% output.pbm
```

`-lat WxH+offset%` — 局部自适应阈值。窗口大小 `WxH` 应略大于笔画宽度，`offset` 控制灵敏度。适合手机拍照的不均匀光照。

### 去噪（形态学）

```bash
magick input.png -colorspace Gray -normalize \
    -morphology Open Disk:1.5 \
    -threshold 50% output.pbm
```

`-morphology Open` 先腐蚀后膨胀，去除比结构元素小的噪点。

### 去噪（中值滤波）

```bash
magick input.png -colorspace Gray -median 3 -threshold 50% output.pbm
```

`-median` 对椒盐噪点特别有效。

### 锐化（模糊照片）

```bash
magick input.png -colorspace Gray -unsharp 0x2+1+0 -threshold 50% output.pbm
```

`-unsharp radius x sigma + amount + threshold` — 先锐化再二值化，可恢复部分模糊细节。

## 彩色 SVG（色彩分离）

Potrace 只处理二值图。要保留颜色需对每种颜色单独描摹后合并：

```bash
for color in "#000000" "#FF0000" "#0000FF"; do
    magick input.png -fill white +opaque "$color" \
        -fill black -opaque "$color" \
        -colorspace Gray -threshold 50% pbm:- \
    | potrace --svg --color "$color" -o "layer_${color}.svg"
done
```

然后用文本编辑或 `svgo` 合并各层到一个 SVG。

## 推荐调参流程

1. 先用默认 `auto` preset 跑一遍
2. 检查 SVG 输出：
   - **太多噪点** → 增大 `turdsize`（15–25）
   - **线条锯齿** → 增大 `alphamax`（1.0–1.3）
   - **细节丢失** → 减小 `turdsize`（2–5），减小 `opttolerance`（0.1）
   - **文件太大** → 增大 `opttolerance`（0.3–0.5）
   - **光照不均导致半边消失** → 改用 `-lat` 自适应阈值替代固定 `-threshold`
3. 用 `custom` preset 传入调整后的参数重跑
