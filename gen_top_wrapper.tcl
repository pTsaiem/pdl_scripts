#################CREATING THE TOP WRAPPER###################
proc Pcreate_top { controller_block unit_list chain_map } {

	puts "//beginning top creation...."

	puts "module top_wrapper #(
	localparam APB_WIDTH = 32
    ,localparam APB_ADDR_WIDTH = 10
    ,localparam JACKET_WIDTH = 8 
)
("
	####### top wrapper in/outputs
	
	#list of unit modules
	set modules {}
	foreach key [dict keys $unit_list] {
		set module [dict get $unit_list $key]
		if { $module in $modules } {
			continue
		} else {
			lappend modules [dict get $unit_list $key] 
		} 
	}

	if { $controller_block != "" } {
		lappend modules $controller_block
	}
	set ports [Pbuild_top_interface $modules]
	set has_dft 0
	foreach port $ports	{
		if { [regexp "\.\*DFT_\.\*" $port match] } {
			set has_dft 1
		}
		set temp "\t${port}"
		puts  "${temp},"
	}
	if { $controller_block == "" } {	
	puts "
\tinput \tfc2ch_ready,
\tinput \tfc2ch_data,
\toutput \[[expr [llength $chain_map] - 1]:0\]\tch2fc_data,
\toutput \[[expr [llength $chain_map] - 1]:0\]\tch2fc_intr,
\tinput prtn_clk;
\tinput p1rst_n;
\n\n"
	}
	set unit_count 0
	foreach unit_no [join $chain_map] {
		set temp "\tinput r1clk_u${unit_no}"
		if { $unit_count != [llength [join $chain_map]]-1 } {
			puts  "${temp},"
		} else {
			puts "$temp"
		}
		incr unit_count
	}

	puts ");\n"

	if { $controller_block != "" } {	
	puts "
\twire \tfc2ch_ready;
\twire \tfc2ch_data;
\twire \[[expr [llength $chain_map] - 1]:0\]\tch2fc_data;
\twire \[[expr [llength $chain_map] - 1]:0\]\tch2fc_intr;
\twire prtn_clk;
\twire p1rst_n;
\n\n"
	}

	############## DFT chain wires
	if { $has_dft == 1 } {
		puts "\twire \[49:0\] DFT_chain_from_controller;"
		set unit_count 0
		foreach unit_no [join $chain_map] {
			set temp "\twire \[49:0\] DFT_chain_from_unit${unit_no};"
			puts "$temp"
			incr unit_count
		}
	}
	


	###########Create FC and Connect to Units
	if { $controller_block != "" } {
		set controller_ins [Pcreate_controller_instance $controller_block]
		foreach line $controller_ins {
			puts "$line"
		}
	}
	#
	#
	#
	##########Create Units and Connect Them
	set unit_ins [ Pcreate_unit_instances $chain_map $unit_list ]
	foreach line $unit_ins {
		puts "$line"
	}


	puts "endmodule"

};#proc_end Pcreate_top

###################INSTANTIATING THE CONTROLLER BLOCK#################
proc Pcreate_controller_instance { controller_block } {
	set pins [Pgrab_interface $controller_block]
	set controller_ins {"\n\n"}
	set pin_no 0
	lappend controller_ins "\n\n//the block with fc is: $controller_block\n\n\n"
	lappend controller_ins "$controller_block ${controller_block} ("
	foreach pin $pins {
		set pin [ regsub -all {.*put|\s\s\s+|^\s+|;|,|\/\/.*|\[.*\]| } $pin ""]
		
		if { [regexp -nocase "DFT_SO" $pin a type] } {
			set temp "\t.${pin}(DFT_chain_from_controller)"
		} else {
			set temp "\t.${pin}(${pin})"
		}
		if { $pin_no == [llength $pins]-1 } {
			lappend controller_ins "$temp"
		} else {
			lappend controller_ins "${temp},"
		}
		incr pin_no
	}
	lappend controller_ins ");\n\n\n"
	return $controller_ins
}

###################INSTANTIATING THE UNITS#################
proc Pcreate_unit_instances {chain_map unit_list} {
	set wire_list {}
	set unit_ins {"\n\n\n"}
	set chain_no 	0
	set unit_ins_no 0
	set unit_ids [join $chain_map]
	set id_count 0
	foreach chain $chain_map {
		lappend unit_ins "//In chain $chain_no, the units are:\n"
		set unit_no 	0
		foreach unit $chain {
			set pin_no 0
			set pins [Pgrab_interface [dict get $unit_list [lindex [dict keys $unit_list] $unit_ins_no ]]]
			lappend unit_ins " [dict get $unit_list [lindex [dict keys $unit_list] $unit_ins_no ]] [lindex [dict keys $unit_list] $unit_ins_no ] ("
			foreach pin $pins {
				set pin [ regsub -all {.*put|\s\s\s+|^\s+|;|,|\/\/.*|\[.*\]| } $pin ""]
				if {$pin == "selfid"} {
					set temp "\t.${pin}(10'd[lindex [lindex $chain_map $chain_no ] $unit_no])"
				} elseif { [regexp -nocase "fc2un\.\*(data|intr|ready)\.\*daisy\.\*in" $pin a type] } {
					if { [expr ${unit_no}] > 0 } {
						set pin_ins "wire_fc2un_${type}_daisy_ch${chain_no}_u[lindex $chain [expr ${unit_no}-1] ]"
					} else {
						set pin_ins "fc2ch_${type}"
					}
					set temp "\t.${pin}(${pin_ins})"
				} elseif { [regexp -nocase "un2fc\.\*(data|intr|ready)\.\*daisy\.\*in" $pin a type] } {
					if { [expr ${unit_no}+1] < [llength $chain] } {
						set pin_ins "wire_un2fc_${type}_daisy_ch${chain_no}_u[lindex $chain [expr ${unit_no}+1] ]"
					} else {
						set pin_ins "1'b0"
					}
					set temp "\t.${pin}(${pin_ins})"
					#set temp "\t.${pin}(wire_un2fc_${type}_daisy_ch${chain_no}_u[expr ${unit_no}+1])"
				} elseif { [regexp -nocase "fc2un\.\*(data|intr|ready)\.\*daisy\.\*out" $pin a type] } {
					if { [expr ${unit_no}+1]  < [llength $chain] } {
						set pin_ins "wire_fc2un_${type}_daisy_ch${chain_no}_u[lindex $chain [expr ${unit_no}] ]"
					} else {
						set pin_ins ""
					}
					set temp "\t.${pin}(${pin_ins})"
					#set temp "\t.${pin}(wire_fc2un_${type}_daisy_ch${chain_no}_u[expr ${unit_no}])"
				} elseif { [regexp -nocase "un2fc\.\*(data|intr|ready)\.\*daisy\.\*out" $pin a type] } {
					if { [expr ${unit_no}] > 0 } {
						set pin_ins "wire_un2fc_${type}_daisy_ch${chain_no}_u[lindex $chain [expr ${unit_no}] ]"
					} else {
						set pin_ins "ch2fc_${type}\[${chain_no}\]"
					}
					set temp "\t.${pin}(${pin_ins})"
					#set temp "\t.${pin}(wire_un2fc_${type}_daisy_ch${chain_no}_u[expr ${unit_no}])"
				} elseif { [regexp -nocase "prtn_clk\.\*daisy\.\*out" $pin a type] } {
					if { [expr ${unit_no}+1]  < [llength $chain] } {
						set pin_ins "wire_prtn_clk_daisy_ch${chain_no}_u[lindex $chain [expr ${unit_no}] ]"
					} else {
						set pin_ins ""
					}
					set temp "\t.${pin}(${pin_ins})"
				} elseif { [regexp -nocase "p1rst_n\.\*daisy\.\*out" $pin a type] } {
					if { [expr ${unit_no}+1]  < [llength $chain] } {
						set pin_ins "wire_p1rst_n_daisy_ch${chain_no}_u[lindex $chain [expr ${unit_no}] ]"
					} else {
						set pin_ins ""
					}
					set temp "\t.${pin}(${pin_ins})"
				} elseif { [regexp -nocase "(prtn_clk|p1rst_n)" $pin a type] } {
					if { [expr ${unit_no}] > 0  } {
						set pin_ins "wire_${type}_daisy_ch${chain_no}_u[lindex $chain [expr ${unit_no}-1] ]"
					} else {
						set pin_ins "${type}"
					}
					set temp "\t.${pin}(${pin_ins})"
				} elseif { [regexp -nocase "DFT_SI" $pin a type] } {
					if { $id_count > 0  } {
						set pin_ins "DFT_chain_from_unit[lindex $unit_ids [expr $id_count -1]]"
					} else {
						set pin_ins "DFT_chain_from_controller"
					}
					set temp "\t.${pin}(${pin_ins})"
				} elseif { [regexp -nocase "DFT_SO" $pin a type] } {
					if { $id_count >= [expr [llength $unit_ids] - 1]  } {
						set pin_ins "DFT_SO"
					} else {
						set pin_ins "DFT_chain_from_unit[lindex $unit_ids [expr $id_count]]"
					}
					set temp "\t.${pin}(${pin_ins})"
				} elseif { [regexp -nocase "r1clk$" $pin a type] } {
					set temp "\t.${pin}(${pin}_u[lindex $chain [expr ${unit_no}]])"
				} else {
					set temp "\t.${pin}(${pin})"
				}
				if { $pin_no != [llength $pins]-1 } {
					lappend unit_ins  "${temp},"
				} else {
					lappend unit_ins  $temp
				}
				incr pin_no
				if { [regexp -nocase "wire\.\*" $pin_ins a type] } {
					if { "wire $pin_ins;" in $wire_list } {
						continue
					} else {
						lappend wire_list "wire $pin_ins;"
					}
				}
			}
			lappend unit_ins ");\n\n\n"
			incr unit_no 1
			incr id_count 1
			incr unit_ins_no 1
		}
		incr chain_no 1
	}
	set line_list [concat  $wire_list $unit_ins]
	return $line_list
}; #proc_end Pcreate_unit_instances

###################GRABING THE INTERFACES OF A MODULE#################
proc Pgrab_interface {  module_name } {
	set vfile [open "design/${module_name}.sv" ]
	set lines [split [read $vfile] "\n"]
	close $vfile
	set pins {}
	set start_appending 0
	set line_number 0
	set interface_done 0
	foreach line $lines {
		incr line_number
		if { [regexp -nocase "\.\*module\\s\+${module_name}\\s\.\*" $line a] } {
			for {set i $line_number} { $i < [ llength $lines] } {incr i} {
				if { [regexp -nocase "\.\*put\\s\+(\\S\+)\.\*" [lindex $lines $i] a] && ![regexp -nocase "^\\s\+\/\/" [lindex $lines $i] a]} {
					set pin [ regsub -all {^\s+|;|,|\/\/.*| +$} $a ""]
					set pin [ regsub -all { +$} $pin ""]
					lappend pins $pin	
				} elseif {[regexp -nocase "\\);" [lindex $lines $i] a] } {
					incr interface_done
					break
				}
			}
		} 
		if {$interface_done == 1} break
	}
	return $pins
}; #proc_end Pgrab_interface 

##############BUILDING THE TOP WRAPPER INTERFACE##################
proc Pbuild_top_interface { modules } {
	set all_ports {}
	foreach module $modules {
		set pins [Pgrab_interface $module]
		foreach pin $pins {
			if {[regexp -nocase "selfid|daisy|fc2ch|ch2fc|prtn_clk|p1rst_n" $pin a]} {
				continue
			} elseif { $pin in $all_ports } {
				continue
			} else {
				lappend all_ports $pin
			}
		}
	}
	return $all_ports
}; #proc_end Pbuild_top_interface
