#  File Name:         OsvvmScriptsFileCreate.tcl
#  Purpose:           Scripts for running simulations
#  Revision:          OSVVM MODELS STANDARD VERSION
#
#  Maintainer:        Jim Lewis      email:  jim@synthworks.com
#  Contributor(s):
#     Jim Lewis           email:  jim@synthworks.com
#     Markus Ferringer    Patterns for error handling and callbacks, ...
#
#  Description
#    Tcl procedures to Autogenerate Files
#
#  Developed by:
#        SynthWorks Design Inc.
#        VHDL Training Classes
#        OSVVM Methodology and Model Library
#        11898 SW 128th Ave.  Tigard, Or  97223
#        http://www.SynthWorks.com
#
#  Revision History:
#    Date      Version    Description
#     1/2025   2025.01    Initial
#
#
#  This file is part of OSVVM.
#
#  Copyright (c) 2025 by SynthWorks Design Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

package require fileutil

namespace eval ::osvvm {

# -------------------------------------------------
# FindOsvvmSettingsDirectory
#
proc FindOsvvmSettingsDirectory {{OsvvmSubdirectory "osvvm"}} {
  # When StartUpShared.tcl calls this to determine the value of ::osvvm::OsvvmUserSettingsDirectory, 
  # OsvvmSettingsLocal.tcl has not been run yet, as a result,
  #   * OsvvmSettingsSubDirectory will have its default value of "" and
  #   * SettingsAreRelativeToSimulationDirectory will have its default value of false.
  # For OsvvmSettingsSubDirectory, this is ok as it is only needed to differentiate the VHDL code and not the settings.
  # SettingsAreRelativeToSimulationDirectory this is not ok and it usage has been deprecated. 
  #    This was used to differentiate VHDL sources for different simulators - use OsvvmSettingsSubDirectory instead
  #
  
  set SettingsRootDirectory ${::osvvm::OsvvmHomeDirectory}
  if {$::osvvm::SettingsAreRelativeToSimulationDirectory} {
    puts "WARNING:   SettingsAreRelativeToSimulationDirectory is deprecated.  Usage will generate an error in the future"
    set SettingsRootDirectory [file normalize ${::osvvm::CurrentSimulationDirectory}]
  }

  if {[info exists ::env(OSVVM_SETTINGS_DIR)]} {
    # Note that OSVVM_SETTINGS_DIR may be either a absolute or relative path
    # For relative paths, use OsvvmHomeDirectory (location of OsvvmLibraries) as the base
    set SettingsDirectory $::env(OSVVM_SETTINGS_DIR) 
  } elseif {[file isdirectory ${SettingsRootDirectory}/../OsvvmSettings]} {
    set SettingsDirectory ../OsvvmSettings 
  } else {
    puts "Note: Putting setting in directory OsvvmLibraries/${OsvvmSubdirectory}"
    set SettingsDirectory ${OsvvmSubdirectory} 
  }
  
  set SettingsDirectoryFullPath [file normalize [file join ${SettingsRootDirectory} ${SettingsDirectory} ${::osvvm::OsvvmSettingsSubDirectory}]]
    
  CreateDirectory $SettingsDirectoryFullPath
#  set RelativeSettingsDirectory [::fileutil::relative [pwd] $SettingsDirectoryFullPath]
#  return $RelativeSettingsDirectory
  # Needs to be a normalized path
  return $SettingsDirectoryFullPath
}


# -------------------------------------------------
#  CreateOsvvmScriptSettingsPkg
#
proc CreateOsvvmScriptSettingsPkg {SettingsDirectory} {
  set OsvvmScriptSettingsPkgFile  [file join ${SettingsDirectory} "OsvvmScriptSettingsPkg_generated.vhd"] 
  set NewFileName                 [file join ${SettingsDirectory} "OsvvmScriptSettingsPkg_new.vhd"]   

  set WriteCode [catch {set FileHandle  [open $NewFileName w]} WriteErrMsg]
  if {$WriteCode} { 
    puts "Not able to open OsvvmScriptSettingsPkg_generated.vhd. Using defaults instead" 
    return ""
  }
  puts $FileHandle "-- This file is autogenerated by CreateOsvvmScriptSettingsPkg" 
  puts $FileHandle "package body OsvvmScriptSettingsPkg is" 
  puts $FileHandle "  constant OSVVM_HOME_DIRECTORY         : string := \"[file normalize ${::osvvm::OsvvmHomeDirectory}]\" ;"
  if {${::osvvm::OsvvmTemporaryOutputDirectory} eq ""} {
    puts $FileHandle "  constant OSVVM_RAW_OUTPUT_DIRECTORY   : string := \"\" ;"
  } else {
    puts $FileHandle "  constant OSVVM_RAW_OUTPUT_DIRECTORY   : string := \"${::osvvm::OsvvmTemporaryOutputDirectory}/\" ;"
  }
  if {${::osvvm::OutputBaseDirectory} eq ""} {
    puts $FileHandle "  constant OSVVM_BASE_OUTPUT_DIRECTORY  : string := \"\" ;"
  } else {
    puts $FileHandle "  constant OSVVM_BASE_OUTPUT_DIRECTORY  : string := \"${::osvvm::OutputBaseDirectory}/\" ;"
  }
  puts $FileHandle "  constant OSVVM_BUILD_YAML_FILE        : string := \"${::osvvm::OsvvmBuildYamlFile}\" ;"
  puts $FileHandle "  constant OSVVM_TRANSCRIPT_YAML_FILE   : string := \"${::osvvm::TranscriptYamlFile}\" ;"
  puts $FileHandle "  constant OSVVM_REVISION               : string := \"${::osvvm::OsvvmVersion}\" ;"
  puts $FileHandle "  constant OSVVM_SETTINGS_REVISION      : string := \"${::osvvm::OsvvmVersionCompatibility}\" ;"
  puts $FileHandle "end package body OsvvmScriptSettingsPkg ;" 
  close $FileHandle
  if {[FileDiff $OsvvmScriptSettingsPkgFile $NewFileName]} {
    file rename -force $NewFileName $OsvvmScriptSettingsPkgFile
  } else {
    file delete -force $NewFileName
  }
  return $OsvvmScriptSettingsPkgFile
}


# -------------------------------------------------
#  CreatePathPkg
#
proc CreatePathPkg {BaseName {SettingsDirectory ""}} {
  if {$SettingsDirectory eq ""} {set SettingsDirectory $::osvvm::OsvvmUserSettingsDirectory}
  set TestSettingsPkgFile     [file join ${SettingsDirectory} "${BaseName}PathPkg_generated.vhd"] 
  set NewFileName             [file join ${SettingsDirectory} "${BaseName}PathPkg_new.vhd"]   
  set DefaultSettingsPkgFile  [file join ${SettingsDirectory} "${BaseName}PathPkg_default.vhd"] 

  set WriteCode [catch {set FileHandle  [open $NewFileName w]} WriteErrMsg]
  if {$WriteCode} { 
    puts "Not able to open ${NewFileName}. Using defaults instead" 
    analyze ${BaseName}SettingsPkg_default.vhd
    return ""
  }
  set LocalScriptDir  "[::fileutil::relative ${::osvvm::CurrentSimulationDirectory} [file normalize ${::osvvm::CurrentWorkingDirectory}]]"
  puts $FileHandle "-- This file is autogenerated by CreatePathPkg" 
  puts $FileHandle "package ${BaseName}SettingsPkg is" 
  puts $FileHandle "  constant TEST_PATH_DIR         : string := \"${LocalScriptDir}\" ;"
  puts $FileHandle "  constant TEST_PATH_SET         : boolean := TRUE ;"
  puts $FileHandle "end package ${BaseName}SettingsPkg ;" 
  close $FileHandle
  if {[FileDiff $TestSettingsPkgFile $NewFileName]} {
    file rename -force $NewFileName $TestSettingsPkgFile
  } else {
    file delete -force $NewFileName
  }
  analyze $TestSettingsPkgFile
  return $TestSettingsPkgFile
}


# -------------------------------------------------
#  CreateAndAnalyzeBuildSettingsPkg
#
proc CreateBuildSettingsPkg {BaseName {SettingsDirectory ""}} {
  if {$SettingsDirectory eq ""} {set SettingsDirectory $::osvvm::OsvvmUserSettingsDirectory}
  set TestSettingsPkgFile     [file join ${SettingsDirectory} "${BaseName}SettingsPkg_generated.vhd"] 
  set NewFileName             [file join ${SettingsDirectory} "${BaseName}SettingsPkg_new.vhd"]   
  set DefaultSettingsPkgFile  [file join ${SettingsDirectory} "${BaseName}SettingsPkg_default.vhd"] 

  set WriteCode [catch {set FileHandle  [open $NewFileName w]} WriteErrMsg]
  if {$WriteCode} { 
    puts "Not able to open ${NewFileName}. Using defaults instead" 
    analyze ${BaseName}SettingsPkg_default.vhd
    return ""
  }
  set LocalScriptDir  "[::fileutil::relative ${::osvvm::CurrentSimulationDirectory} [file normalize ${::osvvm::CurrentWorkingDirectory}]]"
  puts $FileHandle "-- This file is autogenerated by CreateBuildSettingsPkg" 
  puts $FileHandle "package ${BaseName}SettingsPkg is" 
  puts $FileHandle "  constant LOCAL_SCRIPT_DIR         : string := \"${LocalScriptDir}\" ;"
  puts $FileHandle "  constant TEST_SUITE_NAME          : string := \"${::osvvm::TestSuiteName}\" ;"
  # Should be in top level OsvvmSettings
  puts $FileHandle "  constant RESULTS_DIR              : string := \"${::osvvm::ResultsDirectory}\" ;"
  if {$::osvvm::Debug} {
    puts $FileHandle "  constant MIRROR_ENABLE            : boolean := TRUE ;"
  } else {
    puts $FileHandle "  constant MIRROR_ENABLE            : boolean := FALSE ;"
  }
  puts $FileHandle "end package ${BaseName}SettingsPkg ;" 
  close $FileHandle
  if {[FileDiff $TestSettingsPkgFile $NewFileName]} {
    file rename -force $NewFileName $TestSettingsPkgFile
  } else {
    file delete -force $NewFileName
  }
  analyze $TestSettingsPkgFile
  return $TestSettingsPkgFile
}

# AutoGenerateFile 
#    Extract from FileName everything up to and including the pattern in the string
#    Write Extracted contents to NewFileName
#    Example call: set ErrorCode [catch {AutoGenerateFile $FileName $NewFileName "--!! Autogenerated:"} errmsg]
proc AutoGenerateFile {FileName NewFileName AutoGenerateMarker} {
  set ReadCode [catch {set ReadFile [open $FileName r]} ReadErrMsg]
  if {$ReadCode} { return }
  set LinesOfFile [split [read $ReadFile] \n]
  close $ReadFile
  
  set WriteCode [catch {set WriteFile  [open $NewFileName w]} WriteErrMsg]
  if {$WriteCode} { return }
  foreach OneLine $LinesOfFile {
    puts $WriteFile $OneLine
    if { [regexp ${AutoGenerateMarker} $OneLine] } {
      break
    }
  }
  close $WriteFile
}


proc FileDiff {File1 File2} {
  set ReadFile1Code [catch {set FileHandle1 [open $File1 r]} ReadErrMsg]
  if {$ReadFile1Code} {return "true"}
  set LinesOfFile1   [split [read $FileHandle1] \n]
  close $FileHandle1
  set LengthOfFile1  [llength $$LinesOfFile1]
  
  set ReadFile2Code [catch {set FileHandle2 [open $File2 r]} ReadErrMsg]
  if {$ReadFile2Code} {return "true"}
  set LinesOfFile2   [split [read $FileHandle2] \n]
  close $FileHandle2
  set LengthOfFile2  [llength $$LinesOfFile2]

  if {$LengthOfFile1 != $LengthOfFile2} {return "true"}
  
  for {set i 0} {$i < $LengthOfFile1} {incr i} {
    if {[lindex $LinesOfFile1 $i] ne [lindex $LinesOfFile2 $i]} {return "true"}
  }
  return "false"
}



# Don't export the following due to conflicts with Tcl built-ins
# map

namespace export CreateOsvvmScriptSettingsPkg FindOsvvmSettingsDirectory CreateAndAnalyzeTestSettingsPkg



# end namespace ::osvvm
}
