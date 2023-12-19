source gen_top_wrapper.tcl

set controller_block "prtn_fc_top"
#set controller_block ""

set unit_list [dict create  prtn_unit_top_u1_id0  prtn_unit_top_u1 prtn_unit_top_u2_id1 prtn_unit_top_u2 prtn_unit_top_u3_id2 prtn_unit_top_u3 prtn_unit_top_u4_id3 prtn_unit_top_u4 prtn_unit_top_u5_id4 prtn_unit_top_u5 prtn_unit_top_u6_id5 prtn_unit_top_u6]

set chain_map { { 0 1 2} {3} {4 5} } 

if { [llength [join $chain_map]] != [ llength [dict keys $unit_list]]} {
	puts "ERROR: Number of ids and unit definitions not matching"
	exit
}

Pcreate_top $controller_block $unit_list $chain_map 

#Pgrab_interface $vpath "prtn_unit_top_unit_top_smsg14lpu"
