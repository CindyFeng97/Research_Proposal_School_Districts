cd "C:\Users\xinme\Dropbox (Penn)\RP"

cap prog drop _all
prog main

	*neighborhood_prep
	*housing_prep
	regdata_prep, point_buffer(0) dist_size(3)

end 

prog neighborhood_prep

	***Neighborhood***
	import excel raw\基本信息+周边.xlsx, sheet("Sheet1") firstrow clear
	
	keep 小区 环线位置 绿化率 容积率 物业费 米地铁数量 米公交站数量 米商场数量 百度经度 百度维度

	* location
	ren *维度 n_lat
	ren *经度 n_lon

	gen inner_ring = strpos(环线位置, "内环以内") !=0
	gen middle_ring = strpos(环线位置, "中环以内") !=0 | strpos(环线位置, "中内环间") !=0 | strpos(环线位置, "内环以外") !=0
	gen outer_ring = strpos(环线位置, "中外环间") !=0 | strpos(环线位置, "中环以外") !=0 
	drop 环线位置

	* neighborhood environment
	replace 绿化率 = subinstr(绿化率, "%", "", .) 
	replace 物业费 = subinstr(绿化率, "元/平米/月", "", .) 
	label var 物业费 "management fee per sqm and month"

	destring *, replace

	ren (绿化率 容积率 物业费 米地铁数量 米公交站数量 米商场数量) (green_ratio floor_to_area_ratio fee n_sub_500m n_bus_500m n_mall_500m)

	gduplicates drop 小区, force
	gen idu = _n
	save inter\neighborhood, replace

end

prog housing_prep

	***Housing Transaction***
	import excel raw\Pudong_202109.xlsx, firstrow clear
	tempfile pudong09
	save `pudong09', replace
	import excel raw\历史成交.xlsx, sheet("Sheet1") firstrow clear
	append using `pudong09'
	

	* data clean
	drop 成交周期天 挂牌价格万 调价次 带看次 关注人 浏览次 户型结构 套内面积 供暖方式 房屋年限 房权所属 AE 挂牌时间 建筑类型 建筑结构 交易权属 梯户比例
	drop if strpos(房屋用途, "商业") !=0 | strpos(房屋用途, "车库") !=0
	 
	foreach var of varlist * {
		replace `var' = "" if `var' == "暂无数据" | `var' == "未知"
	}
	drop if mi(百度经纬)
	keep if AD == "浦东"

	* transaction date 
	foreach exp in " " "成交" "." {
		replace 成交时间 = subinstr(成交时间,"`exp'", "", .)
	}
	gen year = substr(成交时间, 1, 4)
	gen month = substr(成交时间, -4, 2)


	* number of bedrooms
	gen n_bed = substr(房屋户型, 1, 1)
	replace n_bed = "" if n_bed == "-"

	* area, direction
	replace 建筑面积 = subinstr(建筑面积,"㎡", "", .)
	replace 所在楼层 = "3" if strpos(所在楼层, "高") != 0
	replace 所在楼层 = "2" if strpos(所在楼层, "中") != 0
	replace 所在楼层 = "1" if strpos(所在楼层, "低") != 0
	replace 所在楼层 = "0" if strpos(所在楼层, "地") != 0
	gen south = (strpos(房屋朝向,"南")!=0)

	gen elevator = (strpos(配备电梯, "有")!=0)

	* decoration
	gen simply_decorated = strpos(装修情况, "简装") != 0
	gen refined_decorated = strpos(装修情况, "精装") != 0

	* location
	split 百度经纬, p(,)
	ren 百*1 longitude
	ren 百*2 latitude

	* age 
	destring *, replace
	gen age = year - 建成年代
	replace age = 0 if mi(age)
	gen missing_age = mi(age)

	drop 房屋朝向 配备电梯 房屋户型 成交时间 房屋用途 百度经纬 建成年代 装修情况

	ren (成交价格 元平 建筑面积 所在楼层 AD) (price price_sqm area floor district)

	* create crosswalk between neighborhood and households
	preserve 
		merge m:1 小区 using inter\neighborhood, keep(1 3)
		keep if _merge == 1
		drop _merge 
		duplicates drop 小区, force
		gen idm = 小区
		geonear idm latitude longitude using inter\neighborhood, long neighbors(小区 n_lat n_lon) within(5)
		gen LIB1 = idm
		gen LIB2 = 小区
		foreach exp in "小区" "一期" "二期" "三期" "四期" "五期" "(" ")" "弄" "（" "）" "公寓" "别墅" " " {
			replace LIB1 = subinstr(LIB1, "`exp'", "", .)
			replace LIB2 = subinstr(LIB2, "`exp'", "", .)
		}

		strdist LIB1 LIB2

		drop if km > 1.5
		keep if strdist <=5
		bys idm (strdist): keep if _n == 1
		keep idm 小区
			
		disp "Crosswalk created!"
		save inter\crosswalk, replace
	restore 

	ren 小区 idm
	
	merge m:1 idm using inter\crosswalk, keep(1 3) nogen
	replace 小区 = idm if mi(小区)
	merge m:1 小区 using inter\neighborhood, keep(1 3) nogen 
	drop idu
	ren 小区 user_neighborhood
	ren idm neighborhood 
	
	gen transaction_id = _n
	save inter\transaction, replace
	
end

prog regdata_prep

	syntax[anything], point_buffer(str) dist_size(str)
	
	clear 
	cap erase ./inter/regdata.dta
	save ./inter/regdata, replace emptyok
	forv i = 2013/2021 {
		import delimited ./inter/temp/`i'_`point_buffer'_`dist_size'.csv, clear
		append using ./inter/regdata.dta
		save ./inter/regdata, replace
	}
	
	gen deflator = 112.67
	replace deflator = 112.315 if year == 2019
	replace deflator = 109.724 if year == 2018
	replace deflator = 105.599 if year == 2017
	replace deflator = 100.908 if year == 2016
	replace deflator = 100 if year == 2015
	replace deflator = 100.746 if year == 2014
	replace deflator = 99.758 if year == 2013
	gen price_real = (price_sqm/deflator)*100
	gen lprice = log(price_real)
	gen inkey = !mi(saz_id)
	replace saz_id = 0 if mi(saz_id)
	gen yrmth = ym(year, month)
	keep if !mi(user_neighbor)
	
	* label variable
	lab var price_real "Real Price per Square Meter (Base Year: 2016)"
	lab var lprice "Log(Price)"
	lab var inkey "Key School Indicator"
	lab var area "Area in Square Meter"
	lab var south "Face South?"
	lab var n_bed "Number of Beds"
	lab var elevator "Have Elevator?"
	lab var simply_decorated "Simple Decoration"
	lab var refined_decorated "Refined Decoration"
	lab var age "Age of House"
	lab var green_ratio "Green Space Ratio"
	lab var floor_to_area_ "Floor-to-Area Ratio"
	lab var fee "Management Fee"
	lab var n_sub_500m "Number of Subways in 500 meters"
	lab var n_bus_500m "Number of Bus Stops in 500 meters"
	lab var n_mall_500m "Number of Malls in 500 meters"
	lab var inner_ring "Within Inner Ring"
	lab var middle_ring "Inner to Middle Ring"
	lab var outer_ring "Middle to Outer Ring"

	save ./inter/regdata, replace
	
end

main