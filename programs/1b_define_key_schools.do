cd "C:\Users\xinme\Dropbox (Penn)\RP"

set scheme s1mono 
cap prog drop _all

prog main
	crosswalk
	*plot_SAZs
end

prog crosswalk

	* append all school assignments over the year 
	import excel raw/key_schools.xlsx, firstrow clear
	save raw/key_schools, replace

	clear
	cap erase raw/all_schools
	save raw/all_schools, replace emptyok

	forv i = 15/21 {
		if `i' != 17 {
			if `i' == 15 local suf = "xls"
			else local suf = "xlsx"
			import excel raw/`i'.`suf', firstrow clear
			if `i' == 15 ren 情况说明 小区名称
			keep 学校名称 小区名称 对口地段 wgs84 
			gen year = 20`i'
			append using raw/all_schools
			save raw/all_schools, replace
		}
	}
	
	* clean school names 
	gen schoolname = 学校名称
	foreach exp in " " "[" "]" "(" ")" "上海市" "-" "统筹安排"{
		replace schoolname = subinstr(schoolname,"`exp'", "", .)
	}
	drop if mi(schoolname)
	save raw/all_schools, replace
	keep schoolname 
	duplicates drop

	* identify if the assignments are to key schools 
	gen key_school = ""
	gen key = 0
	foreach ind in "张江集团" "建平西校" "市实验" "浦东外国语" "建平实验" "进才实验" "实验学校东校" "菊园" "华夏西校" "清流" "致远" {
		replace key_school = "`ind'" if strpos(schoolname, "`ind'") != 0
		replace key = 1 if strpos(schoolname, "`ind'") != 0
	}

	replace key_school = "建平西校" if strpos(schoolname, "建平") != 0 & strpos(schoolname, "西校") != 0
	replace key = 1 if strpos(schoolname, "建平") != 0 & strpos(schoolname, "西校") != 0

	* 南汇系列
	foreach num in "一" "二" "四" {
		replace key_school = "南汇`num'中" if strpos(schoolname, "南汇") !=0 &  strpos(schoolname, "`num'") !=0
		replace key = 1 if strpos(schoolname, "南汇") !=0 &  strpos(schoolname, "`num'") !=0
	}

	* 进才北
	replace key_school = "进才北校" if strpos(schoolname, "进才") !=0 &  strpos(schoolname, "北") !=0
	replace key = 1 if strpos(schoolname, "进才") !=0 &  strpos(schoolname, "北") !=0

	disp "Crosswalk created!"
	save raw/schoolname_crosswalk, replace
	
	* append crosswalk to the original yearly data
	use raw/all_schools, clear
	merge m:1 schoolname using raw/schoolname_crosswalk, keep(1 3) nogen 
	split wgs84, parse(,)
	ren (wgs841 wgs842 小区名称 对口地段) (longitude latitude neighborhood_name broad_area)
	keep schoolname lon lat year key key_school neighborhood_name broad_area
	destring *, replace
	compress
	lab var schoolname "对口学校"
	lab var key_school "重点学校系统"
	lab var key "1=对口学校是重点"
	save inter/school_assignment, replace

end

prog plot_SAZs

	* 2015 - 2019 changes
	graph drop _all
	foreach i in 2015 2019 {
		local count = `count' + 1
		scatter latitude longitude if key == 1 & year == `i', subtitle("`i'") xtitle("") ytitle("") xlabel(121(0.2)122) name(g`count')
	}

	graph combine g1 g2, title("Change in School Attendance Zones: 2015 - 2019")
	graph export "C:\Users\cinfeng\Desktop\RP\output\SAZ_change.jpg", as(jpg) name("Graph") quality(100) replace
	
end

main