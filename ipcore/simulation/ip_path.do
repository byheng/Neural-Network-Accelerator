# set pathname "F:/FPGA/ziguang/total_project/ipcore";
# set files [glob -nocomplain -directory $pathname *.v];
# foreach file $files {
#     vlog $file;
# }

# # 设置目标文件夹路径
# set folder_path "F:/FPGA/ziguang/total_project/ipcore" 

# # 获取文件夹中所有 .v 文件
# set files [glob -nocomplain -directory $folder_path *.v]

# # 检查是否找到 .v 文件
# if {[llength $files] == 0} {
#     puts "No .v files found in directory: $folder_path"
# } else {
#     # 遍历每个 .v 文件并编译
#     foreach file $files {
#         puts "Compiling file: $file"
#         vlog $file
#     }
# }

# 递归遍历文件夹，查找所有 .v 文件
proc find_v_files {dir file_list} {
    # 获取当前文件夹下的所有文件和子文件夹
    set items [glob -nocomplain -directory $dir *]
    
    # 遍历每个项目
    foreach item $items {
        if {[file isdirectory $item]} {
            # 如果是文件夹，递归调用此函数
            set file_list [find_v_files $item $file_list]
        } elseif {[string match *.v $item]} {
            # 如果是 .v 文件，添加到文件列表
            lappend file_list $item
        }
    }
    
    return $file_list
}

# 设置目标文件夹路径
set folder_path "../../../ipcore"

# 获取所有 .v 文件
set v_files [find_v_files $folder_path {}]

# 检查是否找到 .v 文件
if {[llength $v_files] == 0} {
    puts "No .v files found in directory: $folder_path"
} else {
    # 遍历每个 .v 文件并编译
    foreach file $v_files {
        puts "Compiling file: $file"
        vlog $file
    }
}

# 执行其他操作，或者结束脚本