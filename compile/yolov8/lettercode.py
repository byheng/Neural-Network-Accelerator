from PIL import Image, ImageDraw, ImageFont
import numpy as np
from compile_utils import label_dict


def text_to_bitmap(text, width, height, font_size=12, spacing=2):
    """将文本转换为 01 矩阵，支持字间距调整"""
    # 创建空白图像
    image = Image.new('L', (width, height), color=255)
    draw = ImageDraw.Draw(image)

    # 加载 Times New Roman 字体
    try:
        font = ImageFont.truetype("simsun.ttc", font_size)
    except IOError:
        try:
            font = ImageFont.truetype("simsun.ttc", font_size)
        except IOError:
            raise "error"

    # **逐个字符绘制，增加字间距**
    x, y = 0, 0  # 左对齐，垂直居中
    for char in text:
        draw.text((x, y), char, font=font, fill=0)  # 绘制字符
        char_width = font.getbbox(char)[2] - font.getbbox(char)[0]  # 获取字符宽度
        x += char_width + spacing  # 增加字间距
        if x >= width:  # 防止超出图片宽度
            raise "error"
            break

            # 转换成二进制矩阵（黑色为1，白色为0）
    bitmap = (np.array(image) < 128).astype(int)

    return bitmap


def bitmap_to_c_array(bitmap, var_name="bitmap"):
    """将 01 矩阵转换为 C 语言的 4 字节颜色数组"""
    height, width = bitmap.shape
    c_code = f"{{\n"
    for row in bitmap:
        row_str = ", ".join("0xFFFFFFFF" if val == 1 else "0x00000000" for val in row)
        c_code += f"    {{{row_str}}},\n"
    c_code = c_code[:-1]
    c_code += "},"
    return c_code


c = ""
for label in label_dict:
    bitmap = text_to_bitmap(label, 48, 16)
    c_code = bitmap_to_c_array(bitmap)
    c += c_code
with open("bitmap_output.c", "w") as f:
    f.write(c)
