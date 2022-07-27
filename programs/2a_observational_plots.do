cd "C:\Users\xinme\Dropbox (Penn)\RP"
set scheme s1color

cap prog drop _all
prog main
	
	*housing_price_ts
	*rdplots
	*descriptive_stats
end 

prog housing_price_ts
	
/*
	import excel "raw/shanghai_house_price.xlsx", firstrow clear
	keep B C D
	ren (C D) (year month)
	gen deflator = 112.67
	replace deflator = 112.315 if year == 2019
	replace deflator = 109.724 if year == 2018
	replace deflator = 105.599 if year == 2017
	replace deflator = 100.908 if year == 2016
	replace deflator = 100 if year == 2015
	replace deflator = 100.746 if year == 2014
	replace deflator = 99.758 if year == 2013
	gen price_real_ceic = (B/deflator)*100
	gen yrmth = ym(year, month)
	keep yrmth price_real_ceic
	
	tempfile ceic
	save raw/shanghai_house_price, replace
*/
	
	***Housing Transaction***
	import excel raw\Pudong_202109.xlsx, firstrow clear
	tempfile pudong09
	save `pudong09', replace
	import excel raw\历史成交.xlsx, sheet("Sheet1") firstrow clear
	append using `pudong09'
	
	ren 元平 price_sqm 
	keep 成交时间 price_sqm
	
	* transaction date 
	foreach exp in " " "成交" "." {
		replace 成交时间 = subinstr(成交时间,"`exp'", "", .)
	}
	gen year = substr(成交时间, 1, 4)
	gen month = substr(成交时间, -4, 2)
	destring *, replace
	gen yrmth = ym(year, month)
	drop 成交时间 month
	
	* drop outlier
	qui sum price_sqm, d
	drop if price_sqm <`r(p1)'
	qui sum price_sqm, d
	drop if price_sqm > `r(p99)'
	gen deflator = 112.67
	replace deflator = 112.315 if year == 2019
	replace deflator = 109.724 if year == 2018
	replace deflator = 105.599 if year == 2017
	replace deflator = 100.908 if year == 2016
	replace deflator = 100 if year == 2015
	replace deflator = 100.746 if year == 2014
	replace deflator = 99.758 if year == 2013
	gen price_real = (price_sqm/deflator)*100
	
	collapse (mean) y = price_real (semean) se_y = price_real, by(yrmth)
	
	sort yrmth
	merge 1:1 yrmth using raw/shanghai_house_price, keep(1 3) nogen
	
	gen yu = y + 1.96*se_y
	gen yl = y - 1.96*se_y
	
	format yrmth %tm
	
	local line1 = ym(2013, 3)
	local line2 = ym(2020, 3)
	local line3 = ym(2021, 3)

	local start = ym(2015,1)
	local end = ym(2021, 12)
	twoway (rarea yu yl yrmth if yrmth>=ym(2015, 1), color(gs8) fcolor(gs8) fintensity(inten10)) ///
	(line price_real_ceic yrmth if yrmth>=ym(2015, 1), color(red) msize(vtiny)) ///
	(line y yrmth if yrmth>=ym(2015, 1), color(blue) msize(vtiny)), xtitle("Calendar Month") ///
	ytitle("Real Price per Square Meter") legend(off) xline(`line1' `line2' `line3', lpattern(dash)) ///
	title("Average Housing Price in Shanghai, 2015-2021") xlabel(`start'(24)`end') ///
	note("Variable: Real Price per Square Meter (Base Year: 2016)" "Blue Line: Lianjia Resale Transactions (280, 924 Observations)" "Red Line: National Bureau of Statistics Existing Houses")
	
	graph export "./output/average_housing_price_shanghai_comparison.png", replace

	sort yrmth
	foreach var of varlist price_real y {
		gen `var'_gr = (`var'[_n] - `var'[_n-1])/`var'[_n-1]
	}
	
	local line1 = ym(2014, 3)
	local line2 = ym(2020, 3)
	local line3 = ym(2021, 3)

	local start = ym(2015,1)
	local end = ym(2021, 12)
	twoway (line y_gr yrmth if yrmth>=ym(2015, 1), color(blue)) ///
	(line price_real_ceic_gr yrmth if yrmth>=ym(2015, 1), color(red) msize(vtiny)), xtitle("Calendar Month") ///
	ytitle("Percentage Change of Real Price per Square Meter") legend(off) xline(`line1' `line2' `line3', lpattern(dash)) ///
	title("Housing Price Fluctuation in Shanghai, 2015-2021") xlabel(`start'(24)`end') ///
	note("Variable: Percentage Change of Real Price per Square Meter (Base Year: 2016)" "Blue Line: Lianjia Resale Transactions (280, 924 Observations)" "Red Line: National Bureau of Statistics Existing Houses")
	graph export "./output/fluctuation_rate_shanghai_comparison.png", replace

	****PUDONG SPECIFICALLY****
	***Housing Transaction***
	use ./inter/regdata, clear
	
	* drop outlier
	qui sum price_sqm, d
	drop if price_sqm <`r(p1)'
	qui sum price_sqm, d
	drop if price_sqm > `r(p99)'
	replace price_real = (price_sqm/deflator)*100
	
	collapse (mean) y = price_real (semean) se_y = price_real, by(yrmth)
	
	sort yrmth
	merge 1:1 yrmth using raw/shanghai_house_price, keep(1 3) nogen
	
	gen yu = y + 1.96*se_y
	gen yl = y - 1.96*se_y
	
	format yrmth %tm
	
	local line1 = ym(2014, 3)
	local line2 = ym(2020, 3)
	local line3 = ym(2021, 3)

	local start = ym(2015,1)
	local end = ym(2021, 9)
	twoway (rarea yu yl yrmth if yrmth>=ym(2015, 1), color(gs8) fcolor(gs8) fintensity(inten10)) ///
	(line y yrmth if yrmth>=ym(2015, 1), color(blue) msize(vtiny)), xtitle("Calendar Month") ///
	ytitle("Real Price per Square Meter") legend(off) xline(`line1' `line2' `line3', lpattern(dash)) ///
	title("Average Housing Price in Pudong, 2015-2021") xlabel(`start'(24)`end') ///
	note("Variable: Real Price per Square Meter (Base Year: 2016)" "Blue Line: Lianjia Resale Transactions Pudong (49, 374 Observations)")
	
	graph export "./output/average_housing_price_pudong.png", replace

end

prog rdplots
	
	use ./inter/regdata.dta, replace
	
	graph drop _all
	sum price_real, d
	drop if price_real >= 107069
	replace distance = distance*100000
	local cutoff = 1000
	replace distance = -distance if inkey == 0
	
	rdplot price_real distance if abs(distance)<`cutoff', nbins(10) c(0) xlabel(-1000(`cutoff')1000) xtitle("Distance to School District Boundary") p(4) graph_options(xtitle("Distance to Boundary") ytitle("Real Housing Price per Square Meter") xline(0, lcolor(red)) legend(off) name(gs1)) 
	
	rdplot green_ratio distance if abs(distance)<`cutoff' & green_ratio>30, nbins(10) c(0) xlabel(-1000(`cutoff')1000) xtitle("Distance to School District Boundary") graph_options(xtitle("Distance to Boundary") ytitle("Green Space Ratio") legend(off) name(gs2) xline(0, lcolor(red))) 
	
	rdplot age distance if abs(distance)<`cutoff' & inrange(age, 18, 25), nbins(10) c(0) xlabel(-1000(`cutoff')1000) graph_options(xtitle("Distance to Boundary") ytitle("Building Age") legend(off) name(gs3) xline(0, lcolor(red))) 
	
	rdplot n_sub_500m distance if abs(distance)<`cutoff' & n_sub_500m>0.2, nbins(10) c(0) xlabel(-1000(`cutoff')1000) graph_options(xtitle("Distance to Boundary") ytitle("Number of Subways in 500m") legend(off) name(gs4) xline(0, lcolor(red)))
	
	rdplot n_bus_500m distance if abs(distance)<`cutoff' & n_bus_>5, nbins(10) c(0) xlabel(-1000(`cutoff')1000) graph_options(xtitle("Distance to Boundary") ytitle("Number of Bus Stops in 500m") legend(off) name(gs5) xline(0, lcolor(red))) 
	
	rdplot n_mall_500m distance if abs(distance)<`cutoff', nbins(10) c(0) xlabel(-1000(`cutoff')1000) graph_options(xtitle("Distance to Boundary") ytitle("Number of Malls in 500m") legend(off) name(gs6) xline(0, lcolor(red))) 
	

	graph combine gs1 gs2 gs3 gs4 gs5 gs6, title("(Dis)continuity around Zone Boundary")
	
	graph export "./output/BDD_assumption_plot.png", replace
	
end 

prog descriptive_stats
	
	clear
	use ./inter/regdata, replace
	sum price_real,d 
	keep if price_real < `r(p99)'
	sum lprice,d 
	keep if lprice <`r(p99)'
	
	* local controls
	local var "price_real lprice area n_bed south elevator simply_decorated refined_decorated age green_ratio floor_to_area_ratio n_sub_500m n_bus_500m n_mall_500m inner_ring middle_ring outer_ring"

	estpost summarize `var' 
	
	esttab, cells("mean sd") label

end 

prog rental_stats

	clear 
	import excel raw\历史租房.xlsx, firstrow clear
	* data clean
	keep 小区 面积 建成 朝向 租房成交日期 租金	
	
	replace 建成 = "" if strpos(建成, "未知年代建") !=0
	replace 面积 = subinstr(面积, "平米","",.)
	replace 建成 = subinstr(建成, "年建","",.)
	replace 租金 = subinstr(租金, "元/月","",.)
	gen facesouth = strpos(朝向, "南") !=0
	gen year = substr(租房成交, 1, 4)
	
	destring *, replace 
	gen age = year - 建成
	
	lab var facesouth "% of Houses Facing South"
	lab var 租金 "Rent"
	lab var age "Building Age"
	lab var 面积 "Area"
	
	estpost summarize 租金 面积 age facesouth 
	
	esttab, cells("mean sd") label


end


main