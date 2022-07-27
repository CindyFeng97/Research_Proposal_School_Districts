cd "C:\Users\xinme\Dropbox (Penn)\RP"

cap prog drop _all

prog main

	BDD_output
	
end


prog BDD_output 
		
	use ./inter/regdata, clear
	
	keep if year >=2015
	* local controls
	local hhctrl "area n_bed south elevator simply_decorated refined_decorated age"
	local cmctrl "green_ratio floor_to_area_ratio n_sub_500m n_bus_500m n_mall_500m inner_ring middle_ring outer_ring"
		
	local timefe "yrmth"
	local addtimefe "addfe(`timefe')"
	
	gen post_2021 = yrmth>=ym(2020, 3) & yrmth <=ym(2021, 2)
	gen post_2022 = yrmth >=ym(2021,3)
	gen inter2021 = post_2021*inkey
	gen inter2022 = post_2022*inkey
	
	lab var inter2021 "Post 2021 Reform x Key"
	lab var inter2022 "Post 2022 Reform x Key"
	
// 	ols, y(lprice) x(inkey) `addtimefe'
//	
// 	ols, y(lprice) x(inkey) control(`hhctrl') appendreg `addtimefe'
//	
// 	ols, y(lprice) x(inkey) control(`hhctrl' `cmctrl') appendreg `addtimefe'
	
// 	ols, y(lprice) x(inkey inter2021 inter2022) control(`hhctrl' `cmctrl') addfe(`timefe' bound_id) appendreg 
	
	ols, y(lprice) x(inkey inter2021 inter2022 post*) control(`hhctrl' `cmctrl') addfe(`timefe' bound_id) ///
	condition("if distance<= 0.01") bound_size(1000m) appendreg
	
	ols, y(lprice) x(inkey inter2021 inter2022 post*) control(`hhctrl' `cmctrl') addfe(`timefe' bound_id) ///
	condition("if distance<= 0.005") bound_size(500m) appendreg
	
	ols, y(lprice) x(inkey inter2021 inter2022 post*) control(`hhctrl' `cmctrl') addfe(`timefe' bound_id) ///
	condition("if distance<= 0.0025") bound_size(250m) appendreg
	

end 

prog ols 

	syntax[anything], y(str) x(str) [addfe(str) bound_size(str) condition(str) control(str) appendreg] 
	
	if "`addfe'" != "" local fe "absorb(`addfe')"
	else local fe "noabsorb"
	
	disp "reghdfe `y' `x' `control' `condition', `fe' cl(saz_id)"
	reghdfe `y' `x' `control' `condition', `fe' cl(saz_id)
	
	
	* local regression texts
	foreach text in addhh addcm addbd {
		local `text' "No"
	}

	if strpos("`control'", "n_bed") != 0 local addhh "Yes"
	if strpos("`control'", "n_sub_500m") != 0 local addcm "Yes"
	if strpos("`addfe'", "bound") != 0 local addbd "Yes"
	if "`bound_size'" == "" local bound_size "All Sales"
	local instruct "adjr2 nocons auto(3) addt(BDD Distance, `bound_size', Household Characteristics, `addhh', Neighborhood Characteristics, `addcm', Boundary Fixed Effect, `addbd', Cluster, SAZ) title(Dependent Variable: Log Price Per sqm.)"
	
	* output
	if "`appendreg'" != "" outreg2 using ./output/BDD_total_diff.xls, `instruct' bracket label append excel
	else outreg2 using ./output/BDD_total_diff.xls, `instruct' bracket label replace excel

end 

main