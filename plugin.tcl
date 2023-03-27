### By Damian Brakel ###
set plugin_name "DPx_Flow_Calibrator"

set ::FC_step_number 1
set ::FC_step1_instructions [translate "Fit a portafilter with 0.3mm calibration basket to the machine. Then tap the Activate Test Mode button below"]
set ::FC_step2_instructions [translate "Test mode is active. Start the test by tapping the Espresso button on the group head controller. (stay on this page)"]
set ::FC_step2a_instructions [translate "Test mode is active. Tap the Start Profile button below to run the test"]
set ::FC_step3_instructions [translate "Update Flow Calibration via the button on the lower right. Or run more tests to give a multiple test average"]
set ::FC_error_message [translate "Error! Your results can NOT save"]
set ::FC_error_message_time [translate "Error! Test was too short"]
set ::FC_error_message_pressure [translate "Error! The pressure curve was not flat enough"]
set ::FC_error_message_flow [translate "Error! The flow curve was not flat enough"]
set ::FC_error_message_weight [translate "Error! The weight curve was not flat enough"]
set ::FC_saved_message [translate "Flow calibration has been Updated, please EXIT"]
set ::FC_shortcut_text [translate "turns on/off a shortcut to this page"]
set ::FC_exit_button_description [translate "The Exit button will unload test settings and clear all test data"]

set ::FC_Info_1 [translate "The test requires a bluetooth scale connection. Ensure it's graph is smooth and not picking up machine vibration."]
set ::FC_Info_2 [translate "It is important that the pressure reading is calibrated for accurate flow, I recommend calibrating pressure at 9 bar."]
set ::FC_Info_3 [translate "The test monitors pressure, flow and weight curves and will show an error if the data is not smooth enough."]
set ::FC_Info_4 [translate "The test will not allow a setting < 0.5 or > 1.65. If this occurs, check interference and/or the pressure calibration."]
set ::FC_Info_5 [translate "The pumps flow changes slightly with excessive run time. If testing a lot, consider resting for a < 50% duty cycle."]
set ::FC_Info_6 [translate "If you have questions, please tag me in a post on Diaspora, include a screen shot of the calibration page."]

set ::FC_Info "- $::FC_Info_1 \r- $::FC_Info_2 \r- $::FC_Info_3 \r- $::FC_Info_4 \r- $::FC_Info_5 \r\r $::FC_Info_6"

set ::FC_number_of_samples 10
set ::FC_max_pressure_variation 0.70
set ::FC_max_flow_variation 0.30
set ::FC_max_weight_variation 0.30

namespace eval ::plugins::${plugin_name} {
    variable author "Damian Brakel"
    variable contact "via Diaspora"
    variable description ""
    variable version 1.2.0
    variable min_de1app_version {1.40.1}

    proc build_ui {} {
        # Unique name per page
        set page_name "DPx_Flow_Calibrator"
        dui page add $page_name
        set button_label_colour #333
        set button_outline_width 3
        set button_outline_colour #bbb
        set font_colour #444
        set click_colour #888
        set ::FC_step_info "[translate "Step"] 1:\r$::FC_step1_instructions"
        set ::FC_step_number 1
        set ::FC_test_count 0
        set ::FC_message ""
        set ::FC_last_test_flow 0
        set ::FC_last_test_weight 0
        set ::FC_data_samples 0
        set ::FC_flow_cal_sample_number 0
        set ::FC_average_test_flow 0.001
        set ::FC_average_test_weight 0
        set ::FC_average_test_flow_list {}
        set ::FC_average_test_flow_list {}
        set ::FC_variation_pressure 0
        set ::FC_variation_flow 0
        set ::FC_variation_weight 0
        set ::FC_settings_updated 0
        set ::FC_total_data_length 0

        # Background image and "Done" button
        dui add canvas_item rect $page_name 0 0 2560 1600 -fill "#d7d9e6" -width 0
        dui add canvas_item rect $page_name 10 188 2552 1424 -fill "#ededfa" -width 0
        dui add canvas_item rect $page_name 220 412 2344 1192 -fill #fff -width 3 -outline #e9e9ed
        dui add canvas_item line $page_name 12 186 2552 186 -fill "#c7c9d5" -width 3
        dui add canvas_item line $page_name 2552 186 2552 1424 -fill "#c7c9d5" -width 3
        dui add dbutton $page_name 1034 1250 \
            -bwidth 492 -bheight 120 \
            -shape round -fill #c1c5e4 \
            -label [translate "Exit"] -label_font Helv_10_bold -label_fill #fAfBff -label_pos {0.5 0.5} \
            -command {if {$::settings(skin) == "DSx"} {restore_DSx_live_graph}; set_next_page off off; dui page load off; ::plugins::DPx_Flow_Calibrator::unload_DPx_Flow_Calibrator_test; ::plugins::DPx_Flow_Calibrator::check_FC_step; set ::FC_message ""; set ::FC_test_count 0; set ::FC_settings_updated 0; ::plugins::DPx_Flow_Calibrator::FC_calibrate}
        dui add dtext $page_name 1280 1400 -text $::FC_exit_button_description -font Helv_8 -fill $font_colour -anchor "center" -justify "center"


        # Headline
        #dui add dtext $page_name 1280 300 -text [translate "Flow Calibrator"] -font Helv_20_bold -fill $font_colour -anchor "center" -justify "center"
        dui add variable $page_name 2500 1540 -font Helv_8 -fill $font_colour -anchor e -justify right -textvariable {Version $::plugins::DPx_Flow_Calibrator::version  by $::plugins::DPx_Flow_Calibrator::author}

        dui add variable $page_name 900 450 -font Helv_10 -fill $font_colour -anchor n -justify center -width 1300 -textvariable {$::FC_step_info}
        dui add variable $page_name 900 1100 -font Helv_12_bold -fill #ff9421 -anchor center -justify center -tags FC_message -textvariable {$::FC_message}

        dui add variable $page_name 2000 450 -font Helv_9_bold -fill $font_colour -anchor center -justify center -textvariable {Last Test Data}
        dui add variable $page_name 1700 470 -font Helv_7 -fill $font_colour -textvariable {sampled $::FC_data_samples of $::FC_total_data_length   range}
        dui add variable $page_name 2075 470 -font Helv_7 -fill #00dd00  -textvariable {[round_to_two_digits $::FC_variation_pressure]}
        dui add variable $page_name 2170 470 -font Helv_7 -fill #73ced8 -textvariable {[round_to_two_digits $::FC_variation_flow]}
        dui add variable $page_name 2265 470 -font Helv_7 -fill #a2693d -textvariable {[round_to_two_digits $::FC_variation_weight]}

        dui add variable $page_name 1700 520 -font Helv_9 -fill #4e85f4 -textvariable {[round_to_one_digits $::FC_last_test_flow]mL/s}
        dui add variable $page_name 1950 520 -font Helv_9 -fill #a2693d -textvariable {[round_to_one_digits $::FC_last_test_weight]g/s}

        dui add variable $page_name 2000 630 -font Helv_9_bold -fill $font_colour -anchor center -justify center -textvariable {Average Test Data}
        dui add variable $page_name 1700 650 -font Helv_9 -fill $font_colour -textvariable {Number of tests   [::plugins::DPx_Flow_Calibrator::FC_test_count]}
        dui add variable $page_name 1700 700 -font Helv_9 -fill #4e85f4 -textvariable {[round_to_one_digits $::FC_average_test_flow]mL/s}
        dui add variable $page_name 1950 700 -font Helv_9 -fill #a2693d -textvariable {[round_to_one_digits $::FC_average_test_weight]g/s}


        dui add variable $page_name 2000 820 -font Helv_9_bold -fill $font_colour -anchor center -justify center -textvariable {Flow Calibration Setting}
        dui add variable $page_name 1700 850 -font Helv_9 -fill $font_colour -textvariable {Current setting   $::settings(calibration_flow_multiplier)}
        dui add variable $page_name 1700 900 -font Helv_9 -fill $font_colour -textvariable {Suggested setting   [::plugins::DPx_Flow_Calibrator::FC_flow_cal_suggestion]}
        dui add variable $page_name 320 1490 -font Helv_8 -fill #FFA500 -textvariable {<<  $::FC_shortcut_text}

        dui add dbutton $page_name 650 800 \
            -bwidth 520 -bheight 150 -tags FC_ready_button \
            -label [translate "Activate"]\r[translate "Test Mode"] -label_font Helv_10_bold -label_fill $button_label_colour -label_pos {0.5 0.5} \
            -shape outline -width $button_outline_width -outline $button_outline_colour \
            -command {::plugins::DPx_Flow_Calibrator::load_DPx_Flow_Calibrator_test; ::plugins::DPx_Flow_Calibrator::check_FC_step; set ::FC_test_count 0}
        if {$::settings(ghc_is_installed) == 0} {
            dui add dbutton $page_name 650 800 \
                -bwidth 520 -bheight 150 -tags FC_start_espresso_button -initial_state hidden \
                -label [translate "Start Profile"] -label_font Helv_10_bold -label_fill $button_label_colour -label_pos {0.5 0.5} \
                -shape outline -width $button_outline_width -outline $button_outline_colour \
                -command {if {$::settings(skin) == "DSx"} {DSx_espresso} else {start_espresso}}
        }
        dui add dbutton $page_name 1740 1000 \
            -bwidth 520 -bheight 150 -tags FC_set_calibration_button -initial_state hidden \
            -label [translate "Update Flow"]\r[translate "Calibration"] -label_font Helv_10_bold -label_fill $button_label_colour -label_pos {0.5 0.5} \
            -shape outline -width $button_outline_width -outline $button_outline_colour \
            -command {::plugins::DPx_Flow_Calibrator::FC_update_settings}
        if {$::settings(DamiansFlowCalibratorShortcut) == 1} {
            set ::FC_shortcut_switch_lable [translate "Shortcut"]\r[translate "ON"]
        } else {
            set ::FC_shortcut_switch_lable [translate "Shortcut"]\r[translate "OFF"]
        }
        dui add dbutton $page_name 20 1440 \
            -bwidth 240 -bheight 140 -tags FC_shortcut_switch \
            -labelvariable {$::FC_shortcut_switch_lable} -label_font Helv_8_bold -label_fill #FFA500 -label_pos {0.5 0.5} \
            -shape outline -width $button_outline_width -outline #FFA500 \
            -command {
                if {$::settings(DamiansFlowCalibratorShortcut) == 1} {
                    set ::settings(DamiansFlowCalibratorShortcut) 0
                    set ::FC_shortcut_switch_lable [translate "Shortcut"]\r[translate "OFF"]
                    dui item config off FC_shortcut_button* -initial_state hidden
                    save_settings
                } else {
                    set ::settings(DamiansFlowCalibratorShortcut) 1
                    set ::FC_shortcut_switch_lable [translate "Shortcut"]\r[translate "ON"]
                    dui item config off FC_shortcut_button* -initial_state normal
                    save_settings
                }
            }

        dui add dbutton $page_name 800 200 \
            -bwidth 960 -bheight 200 -initial_state normal \
            -label "Flow Calibrator" -label_font Helv_20_bold -label_fill #444 -label_pos {0.5 0.5} \
            -label1 "\uf05a" -label1_font [dui font get "Font Awesome 5 Pro-Regular-400" 20] -label1_fill #444 -label1_pos {0.9 0.4} \
            -command {dui item show DPx_Flow_Calibrator FC_info_popup*; dui item show DPx_Flow_Calibrator FC_info_popup_b*}

        dui add dbutton $page_name 180 400 \
            -bwidth 2200 -bheight 800 -tags FC_info_popup -initial_state hidden \
            -label "\uf00d" -label_font [dui font get "Font Awesome 5 Pro-Regular-400" 20] -label_fill $button_label_colour -label_pos {0.97 0.1} \
            -label1 $::FC_Info -label1_font Helv_8 -label1_anchor w -label1_justify left -label1_width 2150 -label1_fill $button_label_colour -label1_pos {0.02 0.5} \
            -shape round -fill #fff9C4

        dui add dbutton $page_name 0 0 \
            -bwidth 2560 -bheight 1600 -tags FC_info_popup_b -initial_state hidden \
            -command {dui item hide DPx_Flow_Calibrator FC_info_popup*; dui item hide DPx_Flow_Calibrator FC_info_popup_b*}


        return $page_name
    }
#############
    proc check_versions {} {
        if { [package vcompare [package version de1app] $::plugins::DPx_Flow_Calibrator::min_de1app_version] < 0 } {
            variable description "        * * *  WARNING  * * *\rDPx Flow Calibrator is not compatable with \rApp Version [package version de1app]\rPlease update to version $::plugins::DPx_Flow_Calibrator::min_de1app_version or newer"
        }
        if {$::settings(scale_stop_at_half_shot) !=0 } {
            set ::settings(scale_stop_at_half_shot) 0
        }
    }
    check_versions

    # Testing shortcut
    if {[info exists ::settings(DamiansFlowCalibratorShortcut)] != 1} {
        set ::settings(DamiansFlowCalibratorShortcut) 0
    }
    if {$::settings(skin) == "DSx"} {
        dui add dbutton off 880 0 -bwidth 800 -bheight 200 -tags FC_shortcut_button \
        -shape outline -width 3 -outline #FFA500 -initial_state normal \
        -label [translate "Shortcut to Flow Calibrator"] -label_font Helv_6 -label_fill #FFA500 -label_pos {0.5 0.9} \
        -command {page_to_show_when_off DPx_Flow_Calibrator}
    }
    if {$::settings(skin) == "Insight" || $::settings(skin) == "Insight Dark"} {
        dui add dbutton off 2030 700 -bwidth 520 -bheight 240 -tags FC_shortcut_button \
        -shape outline -width 3 -outline #FFA500 -initial_state normal \
        -label [translate "Shortcut to Flow Calibrator"] -label_font Helv_6 -label_fill #FFA500 -label_pos {0.5 0.9} \
        -command {page_to_show_when_off DPx_Flow_Calibrator}
    }
    if {$::settings(DamiansFlowCalibratorShortcut) == 0} {
        dui item config off FC_shortcut_button* -initial_state hidden
    }


    proc check_FC_step {} {
        if {$::FC_step_number == 3} {
            set ::FC_step_info "[translate "Step"] 3:\r$::FC_step3_instructions"
            dui item show DPx_Flow_Calibrator FC_set_calibration_button*
            dui item hide DPx_Flow_Calibrator FC_ready_button*
            if {$::settings(ghc_is_installed) == 0} {
                dui item show DPx_Flow_Calibrator FC_start_espresso_button*
            }
        } elseif {$::FC_step_number == 2} {
            dui item hide DPx_Flow_Calibrator FC_set_calibration_button*
            if {$::settings(ghc_is_installed) == 0} {
                set ::FC_step_info "[translate "Step"] 2:\r$::FC_step2a_instructions"
                dui item show DPx_Flow_Calibrator FC_start_espresso_button*
                dui item hide DPx_Flow_Calibrator FC_ready_button*
            } else {
                set ::FC_step_info "[translate "Step"] 2:\r$::FC_step2_instructions"
                dui item hide DPx_Flow_Calibrator FC_ready_button*
            }
        } else {
            set ::FC_step_info "[translate "Step"] 1:\r$::FC_step1_instructions"
            dui item show DPx_Flow_Calibrator FC_ready_button*
            dui item hide DPx_Flow_Calibrator FC_start_espresso_button*
            dui item hide DPx_Flow_Calibrator FC_set_calibration_button*
        }
    }

    proc FC_test_count {} {
        if {$::FC_test_count < 0} {
            set ::FC_test_count 0
        }
        return $::FC_test_count
    }

    proc load_DPx_Flow_Calibrator_test {} {
        set ::fc_backup_settings(advanced_shot) $::settings(advanced_shot)
        set ::fc_backup_settings(profile_language) $::settings(profile_language)
        set ::fc_backup_settings(author) $::settings(author)
        set ::fc_backup_settings(profile_title) $::settings(profile_title)
        set ::fc_backup_settings(profile) $::settings(profile)
        set ::fc_backup_settings(profile_filename) $::settings(profile_filename)
        set ::fc_backup_settings(original_profile_title) $::settings(original_profile_title)
        set ::fc_backup_settings(profile_notes) $::settings(profile_notes)
        set ::fc_backup_settings(final_desired_shot_weight) $::settings(final_desired_shot_weight)
        set ::fc_backup_settings(final_desired_shot_weight_advanced) $::settings(final_desired_shot_weight_advanced)
        set ::fc_backup_settings(final_desired_shot_volume_advanced) $::settings(final_desired_shot_volume_advanced)
        set ::fc_backup_settings(final_desired_shot_volume_advanced_count_start) $::settings(final_desired_shot_volume_advanced)
        set ::fc_backup_settings(settings_profile_type) $::settings(settings_profile_type)
        set ::fc_backup_settings(preheat_temperature) $::settings(preheat_temperature)
        set ::fc_backup_settings(espresso_max_time) $::settings(espresso_max_time)
        set ::fc_backup_settings(espresso_temperature) $::settings(espresso_temperature)
        set ::fc_backup_settings(espresso_temperature_0) $::settings(espresso_temperature_0)
        set ::fc_backup_settings(espresso_temperature_1) $::settings(espresso_temperature_1)
        set ::fc_backup_settings(espresso_temperature_2) $::settings(espresso_temperature_2)
        set ::fc_backup_settings(espresso_temperature_3) $::settings(espresso_temperature_3)
        set ::fc_backup_settings(maximum_flow_range_advanced) $::settings(maximum_flow_range_advanced)
        set ::fc_backup_settings(maximum_pressure_range_advanced) $::settings(maximum_pressure_range_advanced)
        set ::fc_backup_settings(beverage_type) $::settings(beverage_type)
        set ::FC_step_number 2

        #######

        set ::settings(advanced_shot) {
            {exit_if 1 flow 7.0 volume 0 max_flow_or_pressure_range 0.2 transition fast exit_flow_under 0 temperature 80.0 weight 0 name fill pressure 8 pump flow sensor coffee exit_type pressure_over exit_flow_over 6 exit_pressure_over 7.0 max_flow_or_pressure 7.5 exit_pressure_under 0 seconds 25.00}
            {exit_if 0 flow 2.0 volume 0 max_flow_or_pressure_range 0.2 transition fast exit_flow_under 0 temperature 80.0 weight 0 name test pressure 8 pump flow sensor coffee exit_type pressure_over exit_flow_over 6 exit_pressure_over 3.0 max_flow_or_pressure 9.0 exit_pressure_under 0 seconds 20.00}
        }
        set ::settings(profile_language) en
        set ::settings(author) Damian
        set ::settings(profile_title) {Damian's flow calibration test}
        set ::settings(profile) {Damian's flow calibration test}
        set ::settings(profile_filename) {Damian's flow calibration test}
        set ::settings(original_profile_title) {Damian's flow calibration test}
        set ::settings(profile_notes) {This flow calibration test requires a scale to be connected
                By Damian Brakel https://www.diy.brakel.com.au/}
        set ::settings(final_desired_shot_weight) 0
        set ::settings(final_desired_shot_weight_advanced) 0
        set ::settings(final_desired_shot_volume_advanced) 0
        set ::settings(final_desired_shot_volume_advanced_count_start) 1
        set ::settings(settings_profile_type) settings_2c

        set ::settings(preheat_temperature) 80
        set ::settings(espresso_max_time) 75.0
        set ::settings(espresso_temperature) 80.0
        set ::settings(espresso_temperature_0) 80.0
        set ::settings(espresso_temperature_1) 80.0
        set ::settings(espresso_temperature_2) 80.0
        set ::settings(espresso_temperature_3) 80.0
        set ::settings(maximum_flow_range_advanced) 0.2
        set ::settings(maximum_pressure_range_advanced) 0.2
        set ::settings(beverage_type) {calibrate}

        if {$::settings(skin) == "DSx"} {
            clear_profile_font
            saw_switch
            save_DSx_settings
            save_settings
            save_settings_to_de1
            profile_has_changed_set_colors
            update_de1_explanation_chart
            fill_profiles_listbox
            LRv2_preview
            DSx_graph_restore
            refresh_DSx_temperature
        } else {
            save_settings
            save_settings_to_de1
            profile_has_changed_set_colors
            update_de1_explanation_chart
            fill_profiles_listbox
        }
    }

    proc unload_DPx_Flow_Calibrator_test {} {
        if {$::settings(profile) == "Damian's flow calibration test" && $::FC_step_number != 1} {
            set ::settings(advanced_shot) $::fc_backup_settings(advanced_shot)
            set ::settings(profile_language) $::fc_backup_settings(profile_language)
            set ::settings(author) $::fc_backup_settings(author)
            set ::settings(profile_title) $::fc_backup_settings(profile_title)
            set ::settings(profile) $::fc_backup_settings(profile)
            set ::settings(profile_filename) $::fc_backup_settings(profile_filename)
            set ::settings(original_profile_title) $::fc_backup_settings(original_profile_title)
            set ::settings(profile_notes) $::fc_backup_settings(profile_notes)
            set ::settings(final_desired_shot_weight) $::fc_backup_settings(final_desired_shot_weight)
            set ::settings(final_desired_shot_weight_advanced) $::fc_backup_settings(final_desired_shot_weight_advanced)
            set ::settings(final_desired_shot_volume_advanced) $::fc_backup_settings(final_desired_shot_volume_advanced)
            set ::settings(final_desired_shot_volume_advanced_count_start) $::fc_backup_settings(final_desired_shot_volume_advanced)
            set ::settings(settings_profile_type) $::fc_backup_settings(settings_profile_type)
            set ::settings(preheat_temperature) $::fc_backup_settings(preheat_temperature)
            set ::settings(espresso_max_time) $::fc_backup_settings(espresso_max_time)
            set ::settings(espresso_temperature) $::fc_backup_settings(espresso_temperature)
            set ::settings(espresso_temperature_0) $::fc_backup_settings(espresso_temperature_0)
            set ::settings(espresso_temperature_1) $::fc_backup_settings(espresso_temperature_1)
            set ::settings(espresso_temperature_2) $::fc_backup_settings(espresso_temperature_2)
            set ::settings(espresso_temperature_3) $::fc_backup_settings(espresso_temperature_3)
            set ::settings(maximum_flow_range_advanced) $::fc_backup_settings(maximum_flow_range_advanced)
            set ::settings(maximum_pressure_range_advanced) $::fc_backup_settings(maximum_pressure_range_advanced)
            set ::settings(beverage_type) $::fc_backup_settings(beverage_type)
            set ::FC_step_number 1
            set ::FC_average_test_flow 0.001
            set ::FC_average_test_weight 0
            set ::FC_average_test_flow_list {}
            set ::FC_average_test_flow_list {}
            if {$::settings(skin) == "DSx"} {
                clear_profile_font
                saw_switch
                save_DSx_settings
                save_settings
                save_settings_to_de1
                profile_has_changed_set_colors
                update_de1_explanation_chart
                fill_profiles_listbox
                LRv2_preview
                DSx_graph_restore
                refresh_DSx_temperature
            } else {
                save_settings
                save_settings_to_de1
                profile_has_changed_set_colors
                update_de1_explanation_chart
                fill_profiles_listbox
            }
        }
    }

    proc FC_update_settings {} {
        if {[FC_flow_cal_suggestion] < 0.5 || [FC_flow_cal_suggestion] > 1.65} {
            dui item config DPx_Flow_Calibrator FC_message -fill #ff574a
            set ::FC_message $::FC_error_message
            after 4000 {set ::FC_message ""}
        } else {
            set ::settings(calibration_flow_multiplier) [::plugins::DPx_Flow_Calibrator::FC_flow_cal_suggestion]
            save_settings
            set ::FC_settings_updated 1
            set_calibration_flow_multiplier $::settings(calibration_flow_multiplier)
            dui item config DPx_Flow_Calibrator FC_message -fill #00dd00
            set ::FC_message $::FC_saved_message
        }
    }

    proc FC_calibrate {} {
        set test 0
        set ::FC_message ""
        set ::FC_avarage_flow ""
        set ::FC_max_flow ""
        set ::FC_min_flow ""
        set ::FC_avarage_weight ""
        set ::FC_max_weight ""
        set ::FC_min_weight ""
        set ::FC_avarage_pressure ""
        set ::FC_max_pressure ""
        set ::FC_min_pressure ""
        set ::FC_variation_pressure ""
        set ::FC_variation_flow ""
        set ::FC_variation_weight ""
        if {$::settings(profile) == "Damian's flow calibration test"} {
            set ::FC_flow_cal_sample_number $::FC_number_of_samples
            set w [espresso_flow_weight range 0 end]
            set ::FC_total_data_length [llength $w]
            if {$::FC_flow_cal_sample_number < 10 || [expr $::FC_total_data_length / 4] < $::FC_flow_cal_sample_number} {
                set test 1
                dui item config DPx_Flow_Calibrator FC_message -fill #ff574a
                set ::FC_data_samples 0
                set ::FC_total_data_length 0
                set ::FC_message $::FC_error_message_time
            } else {
                set w [espresso_flow_weight range 0 end]
                set f [espresso_flow range 0 end]
                set p [espresso_pressure range 0 end]
                set start [expr [llength $p] - $::FC_flow_cal_sample_number]
                set weight_sample [lrange $w $start end]
                set flow_sample [lrange $f $start end]
                set pressure_sample [lrange $p $start end]
                set ::FC_data_samples [llength $weight_sample]
                set ::FC_avarage_flow [::plugins::DPx_Flow_Calibrator::FC_findaverage $flow_sample]
                set ::FC_max_flow [::plugins::DPx_Flow_Calibrator::FC_findmax $flow_sample]
                set ::FC_min_flow [::plugins::DPx_Flow_Calibrator::FC_findmin $flow_sample]
                set ::FC_avarage_weight [::plugins::DPx_Flow_Calibrator::FC_findaverage $weight_sample]
                set ::FC_max_weight [::plugins::DPx_Flow_Calibrator::FC_findmax $weight_sample]
                set ::FC_min_weight [::plugins::DPx_Flow_Calibrator::FC_findmin $weight_sample]
                set ::FC_avarage_pressure [::plugins::DPx_Flow_Calibrator::FC_findaverage $pressure_sample]
                set ::FC_max_pressure [::plugins::DPx_Flow_Calibrator::FC_findmax $pressure_sample]
                set ::FC_min_pressure [::plugins::DPx_Flow_Calibrator::FC_findmin $pressure_sample]
                set ::FC_variation_pressure [expr $::FC_max_pressure - $::FC_min_pressure]
                set ::FC_variation_flow [expr $::FC_max_flow - $::FC_min_flow]
                set ::FC_variation_weight [expr $::FC_max_weight - $::FC_min_weight]

                set ::DBpressure_sample $pressure_sample
                set ::DBflow_sample $flow_sample
                set ::DBweight_sample $weight_sample

                if {$::FC_variation_pressure > $::FC_max_pressure_variation} {
                    set test 1
                    dui item config DPx_Flow_Calibrator FC_message -fill #ff574a
                    set ::FC_message $::FC_error_message_pressure
                }
                if {$::FC_variation_flow > $::FC_max_flow_variation} {
                    set test 1
                    dui item config DPx_Flow_Calibrator FC_message -fill #ff574a
                    set ::FC_message $::FC_error_message_flow
                }
                if {$::FC_variation_weight > $::FC_max_weight_variation} {
                    set test 1
                    dui item config DPx_Flow_Calibrator FC_message -fill #ff574a
                    set ::FC_message $::FC_error_message_weight
                }
            }
        }

        if {$::settings(profile) == "Damian's flow calibration test" && $test !=1} {
            set ::FC_last_test_weight [expr ([join $weight_sample +])/[llength $weight_sample]]
            set ::FC_last_test_flow [expr ([join $flow_sample +])/[llength $flow_sample]]
            lappend ::FC_average_test_weight_list $::FC_last_test_weight
            lappend ::FC_average_test_flow_list $::FC_last_test_flow
            set ::FC_average_test_weight [expr ([join $::FC_average_test_weight_list +])/[llength $::FC_average_test_weight_list]]
            set ::FC_average_test_flow [expr ([join $::FC_average_test_flow_list +])/[llength $::FC_average_test_flow_list]]
        } else {
            set ::FC_test_count [expr {$::FC_test_count - 1}]
            set ::FC_last_test_weight 0
            set ::FC_last_test_flow 0
            set ::FC_data_samples 0
            set ::FC_total_data_length 0
        }
    }

    proc FC_flow_cal_suggestion {} {
        set flow_err_factor [expr ($::FC_average_test_weight / $::FC_average_test_flow)]
        set past_flow_multi $::settings(calibration_flow_multiplier)
        set suggested [round_to_two_digits [expr ($past_flow_multi * $flow_err_factor)]]
        if {$suggested < 0.5 || $suggested > 1.65 || $::FC_settings_updated == 1} {
            return n/a
        } else {
            return $suggested
        }
    }

    proc FC_findaverage {list} {
        if {[llength $list] > 0} {
            set av [expr ([join $list +])/[llength $list]]
            return [round_to_two_digits $av]
        } else {
            return 0
        }

    }

    proc FC_findmax {list} {
        set max 0
        foreach i $list {
            if { $i > $max } {
              set max $i
            }
        }
        return [round_to_two_digits $max]
    }

    proc FC_findmin {list} {
        set min 12
        foreach i $list {
            if { $i < $min } {
              set min $i
            }
        }
        return [round_to_two_digits $min]
    }

    ::de1::event::listener::on_major_state_change_add [lambda {event_dict} {
        if {[dict get $event_dict previous_state] == "Espresso" && $::FC_step_number != 1} {
            set ::FC_message ""
            set ::FC_test_count [expr {$::FC_test_count + 1}]
            set ::FC_step_number 3
            page_to_show_when_off DPx_Flow_Calibrator
            ::plugins::DPx_Flow_Calibrator::check_FC_step
            ::plugins::DPx_Flow_Calibrator::FC_calibrate

        }
    }]

    proc main {} {
        plugins gui DPx_Flow_Calibrator [build_ui]
    }

}
