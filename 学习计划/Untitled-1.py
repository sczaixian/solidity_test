def convert_gbk_to_utf8_safe(input_file, output_file):
    """
    安全版本的GBK转UTF-8转换，处理编码错误
    """
    try:
        # 使用errors='ignore'忽略无法解码的字符
        with open(input_file, 'r', encoding='gbk', errors='ignore') as f_in:
            content = f_in.read()
        
        with open(output_file, 'w', encoding='utf-8') as f_out:
            f_out.write(content)
        
        print(f"转换成功！输出文件: {output_file}")
        
    except Exception as e:
        print(f"转换失败: {str(e)}")

# 使用示例 学习计划\剑卒过河.txt
input_path = "./学习计划/剑卒过河.txt"
output_path = "./剑卒过河2.txt"
convert_gbk_to_utf8_safe(input_path, output_path)