cd "C:\Users\xinme\Dropbox (Penn)\RP"

cap prog drop _all

prog main

	BDD_output
	
end


prog BDD_output 
		
	use ./inter/regdata, clear
	
	* label variable
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
	
	* local controls
	local hhctrl "area n_bed south elevator simply_decorated refined_decorated age"
	local cmctrl "green_ratio floor_to_area_ratio n_sub_500m n_bus_500m n_mall_500m inner_ring middle_ring outer_ring"
	
	global counter = 2014
	forv i = 2015/2021 {
		global counter = $counter + 1
		local timespan "yrmth>=ym(`i', 3) & yrmth<=ym(`i'+1,2)"
		local timefe "month"
		local addtimefe "addfe(`timefe')"
		
		ols, y(lprice) x(inkey) addfe(`timefe' bound_id) ///
				condition("`timespan' & distance<= 0.01") bound_size(1000m) appendreg
		ols, y(lprice) x(inkey) control(`hhctrl' `cmctrl') addfe(`timefe' bound_id) ///
			condition("`timespan' & distance<= 0.005") bound_size(500m) appendreg
		ols, y(lprice) x(inkey) control(`hhctrl' `cmctrl') addfe(`timefe' bound_id) ///
			condition("`timespan' & distance<= 0.0025") bound_size(250m) appendreg
	}

end 

prog ols 

	syntax[anything], y(str) x(str) [addfe(str) bound_size(str) condition(str) control(str) appendreg] 
	
	if "`addfe'" != "" local fe "absorb(`addfe')"
	else local fe "noabsorb"
	
	disp "reghdfe `y' `x' `control' if `condition', `fe' cl(saz_id)"
	reghdfe `y' `x' `control' if `condition', `fe' cl(saz_id)
	
	
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
	if "`appendreg'" != "" outreg2 inkey using ./output/BDD_${counter}.xls, `instruct' bracket label append excel
	else outreg2 inkey using ./output/BDD_${counter}.xls, `instruct' bracket label replace excel

end 

main