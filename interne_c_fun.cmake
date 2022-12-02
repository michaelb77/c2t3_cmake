#[===[ find_extern_lib(Package dir_name tag)
	Set CMAKE var <Package>_DIR to <DEPOTS>/<dir_name> or <EXTERNE_C>/<dir_name> if exists.
#]===]
include(FetchContent)
function(find_extern_lib package dir_name tag)
	#	message("Download or update ${package}")
	if (NOT DEFINED tag)
		set(tag master)
	endif ()
	if (EXISTS "${DEPOTS}/${dir_name}/.git")
		add_subdirectory(${DEPOTS}/${dir_name} ${package})
	elseif (${CMAKE_BUILD_TYPE} STREQUAL "Debug")
		#[[ Only one config can download or it makes conflict. May require reload for other configs
			to get the resulting repo.
		#]]
		#[[ CLion users: Check FETCHCONTENT_FULLY_DISCONNECTED in Settings->Cache variables
			to stop trying download/update.
		#]]
		FetchContent_Declare(${package}
				GIT_REPOSITORY https://tfs.c2t3.net/Librairies/Externe-c/_git/${dir_name}
				GIT_TAG ${tag}
				SOURCE_DIR ${EXTERNE_C}/${dir_name}
				)

		list(APPEND extern_packages ${package})
		set(extern_packages "${extern_packages}" PARENT_SCOPE)
		#		message("extern_packages - ${extern_packages}")

		list(APPEND extern_package_dirs ${dir_name})
		set(extern_package_dirs "${extern_package_dirs}" PARENT_SCOPE)

		list(APPEND extern_package_tags ${tag})
		set(extern_package_tags "${extern_package_tags}" PARENT_SCOPE)

	else ()
		if (EXISTS "${EXTERNE_C}/${dir_name}/.git")
			add_subdirectory(${EXTERNE_C}/${dir_name} ${package})
		else ()
			message("Package does not exist and is not set to be download, check FETCHCONTENT option in cache variable")
		endif ()
	endif ()
endfunction()

#[===[ download_extern_lib(packages dirs tags)
	Downloading the packages that are not already downloaded.
#]===]
function(download_extern_lib packages dirs tags)
	set(failed_packages)
	set(failed_packages_dir)
	foreach (package dir tag IN ZIP_LISTS packages dirs tags)
		if (NOT EXISTS "${EXTERNE_C}/${dir}/.git")
			string(TOLOWER ${package} _package)
			string(TOUPPER ${dir} DIR)

			set(dependency_dir ${CMAKE_CURRENT_BINARY_DIR})
			if (CMAKE_CURRENT_SOURCE_DIR STREQUAL $CACHE{INTERNE_C})
				string(REPLACE "/interne_c" "" dependency_dir ${dependency_dir})
			endif ()

			file(REMOVE "${dependency_dir}/_deps/${_package}-subbuild/${_package}-populate-prefix/src/${_package}-populate-stamp/${_package}-populate-gitinfo.txt")
			list(APPEND failed_packages ${package})
			list(APPEND failed_packages_dir ${dir})
		else ()
			string(TOUPPER ${package} PACKAGE)
			set(FETCHCONTENT_UPDATES_DISCONNECTED_${PACKAGE} ON CACHE BOOL "Stop updating ${package}" FORCE)
		endif ()
	endforeach ()

	FetchContent_MakeAvailable(${packages})

	foreach (package dir IN ZIP_LISTS failed_packages failed_packages_dir)
		if (EXISTS "${EXTERNE_C}/${dir}/.git")
			message(STATUS "Package ${package} have been populated successfully ;)")
		else ()
			message(STATUS "Package ${package} have not been populated :(")
		endif ()
	endforeach ()
endfunction()

#[===[ add_self_to_tests(Package dir_name)
	Add Ceedling project at the path to the list run by CTest.
#]===]
function(add_self_to_tests name ceedling_proj_path)
	add_test(NAME utest_${name}
			COMMAND ceedling test:all
			WORKING_DIRECTORY ${ceedling_proj_path}
			)
endfunction()

function(define_lib_paths)
	#[[
		Define repo paths.
	#]]
	if (NOT DEFINED CACHE{DEPOTS})
		set(depots_path "../..")
		file(REAL_PATH ${depots_path} depots_path)
		set(DEPOTS ${depots_path} CACHE PATH "Repos root")
		message("Setting CACHE:DEPOTS to $CACHE{DEPOTS}")
	endif ()

	# clang-format off
	define_cache_var(INTERNE_C       "$CACHE{DEPOTS}/Lib-interne-c"  "Interne C source root")
	define_cache_var(EXTERNE_C       "$CACHE{DEPOTS}/Lib-externe-c"  "Externe C source root")
	define_cache_var(MODULES         "$CACHE{INTERNE_C}/modules"     "Modules source root")
	define_cache_var(INTERNE_C_CMAKE "$CACHE{INTERNE_C}/cmake"       "Interne C cmake directory")
	# clang-format on
endfunction()

#[===[ define_cache_var(VAR_NAME var_path comment)
	Define cache variable with a guard to avoid redefinition
#]===]
function(define_cache_var VAR_NAME var_path comment)
	if (NOT DEFINED CACHE{${VAR_NAME}})
		set(${VAR_NAME} "${var_path}" CACHE PATH "${comment}")
		message("Setting CACHE:${VAR_NAME} to $CACHE{${VAR_NAME}}")
	endif ()
endfunction()

#[===[ search_if_in_list(hint_pkg list_pkg pkg dir tag)
	Search if a package is in a list and if it is, it will call the find_extern_lib function.
#]===]
function(search_if_in_list hint_pkg list_pkg pkg dir tag)
	#	message("${prefix_id_extern}${hint_pkg} ${${list_pkg}}")
	if ("${prefix_id_extern}${hint_pkg}" IN_LIST ${list_pkg})
		find_extern_lib(${pkg} ${dir} ${tag})
	endif ()
	set(extern_packages "${extern_packages}" PARENT_SCOPE)
	set(extern_package_dirs "${extern_package_dirs}" PARENT_SCOPE)
	set(extern_package_tags "${extern_package_tags}" PARENT_SCOPE)
endfunction()

#[===[ find_dir_names_in_path(path dirs_name_list)
	Find all the directories in a path and return their name in a <dirs_name_list> list
#]===]
function(find_dir_names_in_path path dirs_name_list)
	file(GLOB
			${dirs_name_list}
			LIST_DIRECTORIES TRUE
			${path}/*
			)
	file(GLOB
			FOUND_FILES
			LIST_DIRECTORIES FALSE
			${path}/*
			)
	list(REMOVE_ITEM ${dirs_name_list} ${FOUND_FILES})
	list(TRANSFORM ${dirs_name_list} REPLACE "${path}/" "")

	set(${dirs_name_list} ${${dirs_name_list}} PARENT_SCOPE)
endfunction()

#[===[ option_mod_find_stat(on_list off_list)
	It will fill the first list with the names of the variables that are set to ON
	and the second list with the names of the variables that are set to OFF.
#]===]
function(option_mod_find_stat on_list off_list)
	foreach (inc_gp lib_gp IN ZIP_LISTS ALL_INCLUDE_GP_NAME ALL_LIB_GP_NAME)
		if (${${inc_gp}})
			list(APPEND ${on_list} ${${lib_gp}})
		else ()
			list(APPEND ${off_list} ${${lib_gp}})
		endif ()
	endforeach ()
	set(${on_list} ${${on_list}} PARENT_SCOPE)
	set(${off_list} ${${off_list}} PARENT_SCOPE)
endfunction()

#[===[ get_extern_module_from_list(list ret_list)
	Take a list of modules and return a list of extern modules.
#]===]
function(get_extern_module_from_list list ret_list)
	foreach (mod ${list})
		if (${mod} MATCHES ^${prefix_id_extern})
			list(APPEND ${ret_list} ${mod})
		endif ()
	endforeach ()
	set(${ret_list} ${${ret_list}} PARENT_SCOPE)
endfunction()

#[===[ find_not_cmake_dir(list path ret_list)
	Find all the directories that do not have a CMakeLists.txt file in them.
#]===]
function(find_not_cmake_dir list path ret_list)
	foreach (dir ${list})
		if (NOT EXISTS ${path}/${dir}/CMakeLists.txt)
			list(APPEND ret_list ${dir})
		endif ()
	endforeach ()
	set(${ret_list} ${${ret_list}} PARENT_SCOPE)
endfunction()

#[===[ mod_create_intf(mod_name src inc lib family)
	Unified way to create module interface.
#]===]
function(mod_create_intf mod_name src inc lib family)
	if (${mod_name} MATCHES ^${prefix_id_extern})
		#		message("mod_name ${mod_name}")
	else ()
		foreach (obj ${${lib}})
			if (${obj} IN_LIST lib_ext_pkg)
				list(APPEND tmp_${mod_name} ${obj})
			endif ()
		endforeach ()

		append_to_glob(EXT_LIB_DEP_NAME ${mod_name})
		if ("${tmp_${mod_name}}" STREQUAL "")
			append_to_glob(EXT_LIB_DEP_LIST " ")
		else ()
			append_to_glob(EXT_LIB_DEP_LIST ${tmp_${mod_name}})
		endif ()
		#		message("tmp_${mod_name} ${tmp_${mod_name}}")
		#		message("ext_lib_${mod_name} ${ext_lib_${mod_name}}")
	endif ()

	list(REMOVE_ITEM ${lib} ${lib_ext_pkg})

	if ("mcu" IN_LIST ${lib})
		list(REMOVE_ITEM ${lib} "mcu")
		set(IS_MOD_WITH_MCU true)
	endif ()

	if (IS_MOD_WITH_MCU)
		if (NOT DEFINED mcu_family)
			message("No mcu family currently defined - ${mod_name} module")
			return()
		else ()
			if (${mcu_family} IN_LIST ${family})
				#in list
			else ()
				message("${mcu_family} not defined in ${mod_name} module")
				return()
			endif ()
		endif ()
	endif ()

	# INTERFACE
	add_library(${mod_name}_if INTERFACE)
	target_include_directories(${mod_name}_if INTERFACE
			${CMAKE_CURRENT_LIST_DIR}
			${${inc}}
			${std_dirs}
			)

	# LIB
	add_library(${mod_name} INTERFACE)

	target_sources(${mod_name}
			INTERFACE
			${${src}}
			)

	list(TRANSFORM ${lib} APPEND "_if")

	target_link_libraries(${mod_name}
			INTERFACE
			${mod_name}_if
			${${lib}}
			)
endfunction()

#[===[ add_def_to_prj(tgt)
	Add hardcoded definition to project target
#]===]
function(add_def_to_prj tgt)
	set(prj_def)

	if (${mcu_family} STREQUAL "")
		message("No mcu family defined...")
	else ()
		string(TOUPPER ${mcu_target} MCU_PRJ)
		string(SUBSTRING ${MCU_PRJ} 0 7 MCU_PRJ)
		string(APPEND MCU_PRJ "XX")
		list(APPEND prj_def ${MCU_PRJ})
	endif ()

	search_lib(freertos ret_val_freertos)
	if (ret_val_freertos)
		list(APPEND prj_def "FREERTOS")
	endif ()

	search_lib(json_generator ret_val_json_generator)
	if (ret_val_json_generator)
		list(APPEND prj_def "SRV_MOD_USING_JSON")
	endif ()

	target_compile_definitions(${tgt} PRIVATE ${prj_def})
endfunction()

#[===[ search_lib(lib ret_bool)
	Search lib in list of project dependency. Return true or false on your declared variable.
#]===]
function(search_lib lib ret_bool)
	set(${ret_bool} false)
	set(search_list ${list_prj_lib} ${prj_mod_on})
	list(REMOVE_DUPLICATES search_list)
	set(lib_exp ${lib} ${lib}_if ${prefix_id_extern}${lib})
	#	message("search_list ${lib} ${search_list}")

	foreach (exp ${lib_exp})
		if (${exp} IN_LIST search_list)
			set(${ret_bool} true)
			break()
		endif ()
	endforeach ()

	set(${ret_bool} ${${ret_bool}} PARENT_SCOPE)
endfunction()

#[===[ add_lib_to_prj(tgt ${ARGN})
	Add designated library to project target
	${ARGN} : library list
#]===]
function(add_lib_to_prj tgt)
	#	message("ARGN ${ARGN}")
	target_link_libraries(${tgt} PRIVATE
			${ARGN}
			)
endfunction()

#[===[ get_all_targets(_result _dir)
	Collect all currently added targets in all subdirectories
	_result
		the list containing all found targets
	_dir
		root directory to start looking from
#]===]
function(get_all_targets _result _dir)
	get_property(_subdirs DIRECTORY "${_dir}" PROPERTY SUBDIRECTORIES)
	foreach (_subdir IN LISTS _subdirs)
		get_all_targets(${_result} "${_subdir}")
	endforeach ()

	get_directory_property(_sub_targets DIRECTORY "${_dir}" BUILDSYSTEM_TARGETS)
	set(${_result} ${${_result}} ${_sub_targets} PARENT_SCOPE)
endfunction()

#[===[ find_prj_tgt(ret_result)
	Find project target with ".elf" hint
#]===]
function(find_prj_tgt ret_result)
	set(_results)
	get_all_targets(_results ${CMAKE_BINARY_DIR})
	foreach (result ${_results})
		if (result MATCHES ".*elf")
			list(APPEND ret_result ${result})
			break()
		endif ()
	endforeach ()

	set(${ret_result} ${${ret_result}} PARENT_SCOPE)
endfunction()

#[===[ set_mcu_family(_target _list)
	Search in family list if target is declare and set mcu family for other module
#]===]
function(set_mcu_family _target _list)
	foreach (mcu ${_list})
		if (${_target} MATCHES ^${mcu})
			list(APPEND mcu_family ${mcu})
		endif ()

		set(mcu_family ${mcu_family} PARENT_SCOPE)
	endforeach ()
endfunction()

#[===[ set_prj_toolchain()
	Set project toolchain, take also custom toolchain.
	If you want custom toolchain, copy "arm-gcc-toolchain.cmake" file inside your project folder
	and modify it.
	@Note This need to be set before project call --> project(basic_project C CXX ASM)
#]===]
function(set_prj_toolchain)
	#under development
	if (${Native})
		message(NOTICE "Native")
		enable_language(C ASM)
		return()
	endif ()

	file(GLOB custom_toolchain arm-gcc-toolchain.cmake)

	set(dflt_toolchain_msg "Default toolchain set to ${INTERNE_C}/cmake/arm-gcc-toolchain.cmake")
	set(cust_toolchain_msg "Custom toolchain detect, set to ${custom_toolchain}")
	if (custom_toolchain)
		if (IS_INTERNE_C_PROJECT)
			message(${dflt_toolchain_msg})
		else ()
			message(${cust_toolchain_msg})
		endif ()
		set(CMAKE_TOOLCHAIN_FILE ${custom_toolchain})
	else ()
		message(${dflt_toolchain_msg})
		set(CMAKE_TOOLCHAIN_FILE "${INTERNE_C}/cmake/arm-gcc-toolchain.cmake")
	endif ()

	set(CMAKE_TOOLCHAIN_FILE ${CMAKE_TOOLCHAIN_FILE} PARENT_SCOPE)
endfunction()

#[===[ ensure_toolchain_is_set()
	Ensure toolchain have been define. If not, it will take default toolchain.
#]===]
function(ensure_toolchain_is_set)
	if (NOT DEFINED CMAKE_TOOLCHAIN_FILE)
		set_prj_toolchain()
		set(CMAKE_TOOLCHAIN_FILE ${CMAKE_TOOLCHAIN_FILE} PARENT_SCOPE)
	endif ()
endfunction()

#[===[ prj_set_list_of_dep(ret_list input_list)
	Search every dependency lib set from mod_create_intf().
	Add designated lib to ret_list.
#]===]
function(prj_set_list_of_dep ret_list input_list)
	set(_input_list ${${input_list}})

	set(${ret_list})
	foreach (MODULE ${_input_list})
		#		message("module ${MODULE}_dependency ${${MODULE}_dependency}")
		list(APPEND ${ret_list} ${${MODULE}_dependency})

		string(REPLACE "_dependency" "" module_strip ${MODULE})
		list(APPEND ${ret_list} ${module_strip})
	endforeach ()

	list(REMOVE_DUPLICATES ${ret_list})
	set(${ret_list} ${${ret_list}} PARENT_SCOPE)
endfunction()

#[===[ set_list_of_dep(ret_list input_list)
	Get dependency from interface link library property.
#]===]
function(set_list_of_dep ret_list input_list)
	set(str_dep "_dependency")
	set(${ret_list} ${${input_list}})
	list(TRANSFORM ${ret_list} APPEND ${str_dep}) #spi --> spi_dependency

	foreach (mod mod_dep IN ZIP_LISTS ${input_list} ${ret_list})
		get_target_property(${mod}${str_dep} ${mod} INTERFACE_LINK_LIBRARIES) #spi_dependency (spi_if, log_if...)
		list(TRANSFORM ${mod}${str_dep} REPLACE "_if" "") #spi_dependency (spi, log...)
		#		list(APPEND ${mod}${str_dep} ${ext_lib_${mod}})

		set(${mod}${str_dep} ${${mod}${str_dep}} PARENT_SCOPE)
		#		message("mod ${mod}")
		#		message("${mod_dep} ${${mod_dep}}")
	endforeach ()

	read_glob(EXT_LIB_DEP_NAME dep_name)
	read_glob(EXT_LIB_DEP_LIST dep_list)

	# Reserve to add extern dependency
	foreach (dep list IN ZIP_LISTS dep_name dep_list)
		if (dep IN_LIST ${input_list})
			#remove list of space, space where necessary to keep sync with both list of dep_name, dep_list
			if (NOT ${list} STREQUAL " ")
				list(APPEND ${dep}${str_dep} ${list})
				set(${dep}${str_dep} ${${dep}${str_dep}} PARENT_SCOPE)
			endif ()
		endif ()
	endforeach ()

	set(${ret_list} ${${ret_list}} PARENT_SCOPE)
endfunction()

#[===[ create_glob(var)
	Create internal cache entry, overwrite any existing entry
#]===]
function(create_glob var)
	SET(${var} "${ARGN}" CACHE INTERNAL "Created global var" FORCE)
endfunction()

#[===[ append_to_glob(var ARGN)
	Add additional list to "var".
	Note : empty string are not kept
#]===]
function(append_to_glob var)
	foreach (arg ${ARGN})
		list(APPEND tmp ${arg})
	endforeach ()
	set(tmp_cache $CACHE{${var}})
	list(PREPEND tmp ${tmp_cache})
	create_glob(${var} ${tmp})
endfunction()

#[===[ read_glob(var ret_val)
	Read global variable and return local variable with values read.
#]===]
function(read_glob var ret_val)
	set(${ret_val} $CACHE{${var}})
	set(${ret_val} ${${ret_val}} PARENT_SCOPE)
endfunction()

#[===[ find_if_is_intern_c_prj()
	Determine if workspace root is in Lib-interne-c (defines workspace behavior)
#]===]
function(find_if_is_intern_c_prj)
	set(IS_INTERNE_C_PROJECT false)
	file(REAL_PATH ${CMAKE_BINARY_DIR}/.. bin_up_path)
	if ("$CACHE{INTERNE_C_CMAKE}" STREQUAL ${bin_up_path})
		set(IS_INTERNE_C_PROJECT true)
	endif ()

	set(IS_INTERNE_C_PROJECT ${IS_INTERNE_C_PROJECT} PARENT_SCOPE)
endfunction()

#[===[ ins_prefix_to_specific_item(in_list check_list prefix)
	Search in_list to found item from check_list, if there is a match, a prefix is added to this item.
#]===]
macro(ins_prefix_to_specific_item in_list check_list prefix)
	foreach (obj ${${in_list}})
		if (obj IN_LIST ${check_list})
			list(REMOVE_ITEM ${in_list} ${obj})
			set(obj_temp ${obj})
			string(PREPEND obj_temp ${prefix})
			#			message("found ${obj_temp}")
			list(APPEND ${in_list} ${obj_temp})
		endif ()
	endforeach ()
endmacro()

#[===[ group_modules_under_directory(b_hidden)
	True will hide modules under "modules" directory
#]===]
function(group_modules_under_directory b_hidden)
	set(b_hidden ${b_hidden} PARENT_SCOPE)
endfunction()

function(add_subdir_mod)
	#	list(REMOVE_ITEM mod_to_include ${ext_pkg})
	list(REMOVE_ITEM mod_to_include ${ext_pkg_if})
	list(REMOVE_ITEM mod_to_include ${lib_ext_pkg})

	foreach (MODULE ${mod_to_include})
		add_subdirectory($CACHE{MODULES}/${MODULE} ${MODULE} EXCLUDE_FROM_ALL)
	endforeach ()
endfunction()

#[===[ print_out_for_usr(prj_list)
	Designed to give feedback to user.
#]===]
function(print_output_for_usr prj_list)
	list(SORT ${prj_list} ORDER ASCENDING)

	foreach (obj ${${prj_list}})
		if (obj IN_LIST lib_ext_pkg)
			list(APPEND ext_lib_from_prj ${obj})
		endif ()
	endforeach ()
	set(formted_ext_lib_from_prj ${ext_lib_from_prj})
	list(TRANSFORM formted_ext_lib_from_prj REPLACE "${prefix_id_extern}" "")

	if (mcu_target)
		list(APPEND formted_ext_lib_from_prj "stm32")
	endif ()

	list(REMOVE_ITEM ${prj_list} ${lib_ext_pkg})
	message("Project modules library : ${${prj_list}}")
	message("Project extern library  : ${formted_ext_lib_from_prj}")
	list(PREPEND ${prj_list} ${ext_lib_from_prj})
endfunction()
