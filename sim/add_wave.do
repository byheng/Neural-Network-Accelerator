# dynamic_axi_group_no_wave_new.do
# 功能：清空当前波形窗口，重新分组 AXI 信号和其他信号

# 输入模块路径
set MODULE_PATH $1

# 检查是否提供模块路径
if {$MODULE_PATH == ""} {
    echo "Error: No module path provided. Usage: do dynamic_axi_group_no_wave_new.do <MODULE_PATH>"
    return
}

# 清空当前波形窗口
view -new wave

# AXI 信号分类规则
set axi_channels {
    {axi_ar "AXI Read Address Channel"} 
    {axi_aw "AXI Write Address Channel"} 
    {axi_r  "AXI Read Data Channel"} 
    {axi_w  "AXI Write Data Channel"} 
    {axi_b  "AXI Write Response Channel"}
}

# 参数规则
set param_channels {
    {order					    }
    {feature_input_base_addr	}
    {feature_input_patch_num	}
    {feature_output_patch_num	}
    {feature_double_patch		}
    {feature_patch_num		    }
    {row_size					}
    {col_size					}
    {weight_quant_size		    }
    {fea_in_quant_size		    }
    {fea_out_quant_size		    }
    {stride					    }
    {return_addr				}
    {return_patch_num		   	}
    {padding_size				}
    {weight_data_length		    }
}

# 遍历模块下的所有信号
set all_signals [find signals $MODULE_PATH/*]
foreach signal $all_signals {
    # 提取信号名称
    set signal_name [file tail $signal]

    # 默认分组为 "Other Signals"
    set grouped 0

    # 按 AXI 规则进行分组
    foreach group $axi_channels {
        # 获取前缀和分组名称
        set prefix [lindex $group 0]
        set group_name [lindex $group 1]
        if {[string match *$prefix* $signal_name]} {
            # 将信号添加到对应的 AXI 分组
            add wave -group $group_name $signal
            set grouped 1
            break
        }
    }

    if {$grouped == 0} {
        foreach group $param_channels {
            # 获取前缀和分组名称
            set prefix [lindex $group 0]
            if {[string match *$prefix* $signal_name]} {
                # 将信号添加到对应的 AXI 分组
                add wave -group "Parameter Signals" $signal
                set grouped 1
                break
            }
        }
    }

    # 如果未匹配到 AXI 分组，则添加到默认分组
    if {!$grouped} {
        add wave -group "Other Signals" $signal
    }
}

# 自动调整波形窗口
wave zoom full

echo "Signals from $MODULE_PATH have been grouped successfully!"
