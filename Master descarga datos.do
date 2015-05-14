/*******************************************************************************
AUTHOR: Leonel Fernandez 
DATE: February, 19th 2015
VERSION: 0.4
PURPOSE: Create clean database and indicators of official crime data in Mexico
DATA IN: 
			-IncidenciaDelictiva_FueroComun_Estatal_1997-{MONTH_YEAR}.xls 
			(Raw monthly data of 66 crime types in the 32 federative entities 
			of MŽxico, 1997-actual [Updates in the 20th of each month])
			
			-Incidencia Delictiva FC Municipal 2011 -{YEAR}.xlsx"(Raw monthly 
			data of 66 crime types in all the municipalities 
			of MŽxico, 1997-actual [Updates in the 20th of each month])
			
			-state-population.csv (Cleaned estimated mid-year population data at 
			the state level from the CONAPO (2010) by Diego Valle
			https://github.com/diegovalle/conapo-2010
			
			-municipio-population2010-2030.csv (Cleaned estimated mid-year 
			population data at the municipal level from the CONAPO (2010)
			by Diego Valle.  https://github.com/diegovalle/conapo-2010

			
DATA OUT: 

			-MaestraEstatal.dta
			-MaestraMunicipal.dta
*******************************************************************************/

capture noisily version 13.1
clear all
set more off
capture log close


* Defining globals*
global folder "~/Desktop" 									//<-Change working dir here  
global rates "$folder/Crime rates in Mexico"
global states "$rates/States"
global mun "$rates/Municipalities"
global zm "$rates/Metro Zones"
local logdate = subinstr(trim("$S_DATE"), " ", "_", .)
local dbdate = subinstr(trim(substr("$S_DATE",3,.))," ","_",.)


*Creating working directories
cd "$folder"
capture noisily mkdir "Crime rates in Mexico"
cd "Crime rates in Mexico" 
log using "$rates/`logdate'_update.log", replace
capture noisily mkdir States
capture noisily mkdir Municipalities
capture noisily mkdir "Metro Zones"
cd States
capture noisily mkdir Files
cd ..
cd Municipalities
capture noisily mkdir Files
cd ..
cd "Metro Zones"
capture noisily mkdir Files

/* If the program is not running for the first time, Stata will promt some 
   errors while creating the directories. That is because they were created 
   before. Stata will ignore them, so will you.   					*/



*Downloading datasets. The program needs at least 2.5 GB of Hard Disk free space

/*IMPORTANT:After the 20th of each month check the new URL in SESNSP site and  
			1)Change updated URLs in /*1*/ & /*3*/ 
			2)Chamge updated files names in /*2*/ & /*4*/					*/
			
cd "$states/Files"
/*1*/ copy "http://secretariadoejecutivo.gob.mx/docs/pdfs/incidencia%20delictiva%20del%20fuero%20comun/IncidenciaDelictiva_FueroComun_Estatal_1997-032015.zip" incidencia_e.zip, replace
		unzipfile "incidencia_e.zip", replace
/*2*/ global state_x "$states/Files/IncidenciaDelictiva_FueroComun_Estatal_1997-2015.xlsx"
		copy "$state_x" IncidenciaDelictivaEstatal.xlsx, replace
copy "https://raw.githubusercontent.com/diegovalle/conapo-2010/master/clean-data/state-population.csv" statepop.csv
		
cd "$mun/Files"	
/*3*/ copy "http://secretariadoejecutivo.gob.mx/docs/pdfs/incidencia%20delictiva%20del%20fuero%20comun/IncidenciaDelictiva-Municipal2011-2015.zip" incidencia_m.zip, replace
		unzipfile "incidencia_m.zip", replace
/*4*/ global mun_x "$mun/Files/Incidencia Delictiva FC Municipal 2011 - 2015.xlsb"
		copy "$mun_x" IncidenciaDelictivaMunicipal.xlsx, replace
copy "https://raw.githubusercontent.com/diegovalle/conapo-2010/master/clean-data/municipio-population2010-2030.csv" munpop.csv, replace


****STATE LEVEL CRIME DATA IN MEXICO 1997-ACTUAL*******************************
cd "$states/Files"

*Preparing population data base*
clear
import delimited "$states/Files/statepop.csv"
drop if year > 2015 | year <1997
rename statecode state_code
drop females males 
save statepop.dta, replace


collapse (sum) total, by (year)
gen state_code = 0
gen statename = "NACIONAL"
save statepop_nac.dta, replace
append using statepop.dta
save statepop.dta, replace

*Cleaning SESNSP's crime data set*
clear
import excel using "IncidenciaDelictivaEstatal.xlsx", firstrow
drop if AO == .

**Erase leading, trailing and intermediate blank spaces in all string variables
replace  ENTIDAD = trim(itrim(ENTIDAD))
replace  MODALIDAD = trim(itrim(MODALIDAD))
replace  TIPO = trim(itrim(TIPO))
replace  SUBTIPO = trim(itrim(SUBTIPO))

*Encoding state codes*
encode ENTIDAD, gen(state_code) 

capture noisily drop ENTIDAD TOTALAO

recode state_code (5=45) (6=46)
recode state_code (7=5) (8=6)
recode state_code (45=7) (46=8)

label define state_code 5 "COAHUILA", modify
label define state_code 6 "COLIMA", modify
label define state_code 7 "CHIAPAS", modify
label define state_code 8 "CHIHUAHUA", modify
label define state_code 0 "NACIONAL", add

*Renaming variables*
rename (AO MODALIDAD TIPO SUBTIPO ENERO* FEBRERO* MARZO* ABRIL* MAYO* JUNIO* ///
	JULIO* AGOSTO* SEPTIEMBRE* OCTUBRE* NOVIEMBRE* DICIEMBRE*)(year category ///
	type subtype ene* feb* mar* abr* may* jun* jul* ago* sep* oct* nov* dic*)



*Encoding crime, category, type and subtype
encode category, gen(categoryid)
encode type, gen(typeid)
encode subtype, gen(subtypeid)
label define categoryid 11 "ROBO TOTAL", add
label define categoryid 0"INCIDENCIA DELICTIVA", add
label define typeid 19 "TOTAL",add
label define subtypeid 30 "TOTAL",add



order state*  year *id 

destring ene-dic, replace

save Iestatalmensual.dta, replace


***Totales con o sin violencia por suptipo de robo (Con o sin violencia (typeid))***

*Robo comun**

keep if categoryid == 7 | categoryid == 9 | categoryid == 10

collapse (sum)  ene-dic , by(state_code state  year categoryid subtypeid)
gen typeid:typeid = 19

order state*  year category type subtype

save robo.dta, replace 

************


use Iestatalmensual.dta, clear

***Totales por tipo***
*Total de despojo, homicidio doloso, homicidio culposo, lesiones dolosas, culposas y robo comun con y sin violencia, robo a casa habitaciom
** con y sin violencia, robo a isnt bancarias con y sin violencia**

keep if typeid == 8 | categoryid == 3 | categoryid == 4| categoryid == 7 | categoryid == 9 | categoryid == 10

collapse (sum)  ene-dic  , by(state_code state year categoryid typeid)
gen subtypeid:subtypeid = 30
order state*  year category type subtype

save types.dta, replace




******************
** totales por categoria***

use Iestatalmensual.dta, clear

drop if categoryid == 1 | categoryid == 2 |categoryid == 6 | categoryid == 8
collapse (sum)  ene-dic  , by(state_code state  year categoryid)

gen subtypeid:subtypeid = 30

gen typeid:typeid = 19

order state*  year category type subtype

save categorias.dta, replace

*** total robo **
use Iestatalmensual.dta, clear
keep if categoryid >6
collapse (sum)  ene-dic  , by(state_code state  year typeid)
gen dummy = 1 if typeid ==1 | typeid == 17
replace dummy = 2 if dummy == .
collapse (sum)  ene-dic  , by(state_code state  year dummy)
gen categoryid:categoryid = 11
gen typeid:typeid =4 if dummy == 2
replace typeid =17 if dummy ==1
gen subtypeid:subtypeid =30
drop dummy
save roboviolenciatotal.dta, replace
collapse (sum)  ene-dic  , by(state_code state  year categoryid subtypeid)
gen typeid:typeid =19
save robototal.dta, replace 


** total delitos**
use Iestatalmensual.dta, clear
collapse (sum)  ene-dic  , by(state_code state year)
gen categoryid:categoryid=0
gen typeid:typeid=19
gen subtypeid:subtypeid=30
save total.dta, replace

clear
append using "Iestatalmensual.dta" "robo.dta" "types.dta" "categorias.dta" "roboviolenciatotal.dta" "robototal.dta" "total.dta"

order state* year category type subtype
sort state_code year category type subtype 

save Iestatalmensual.dta, replace


collapse (sum) ene-dic, by (year categoryid typeid subtypeid )
gen state_code:state_code = 0
gen state = "NACIONAL"
append using "Iestatalmensual.dta"
order state* year category type subtype
sort state_code year category type subtype 


/*Creating crime variable wich groups all categories of "ROBO" in just one*

gen crime = category
replace crime = "ROBO" if word(category,1) == "ROBO"
encode crime, gen(crimeid)  
 CHECA!!!!!*/

drop  category type subtype

save Iestatalmensual.dta, replace


**tasas***
merge m:1 year state_code using statepop.dta
drop if year == 2015
drop statename _merge state
rename total pop

foreach var of varlist ene-dic {
	gen t`var' = (`var' * 100000)/ pop
}

save Iestatalmensual.dta, replace
***



drop tene-tdic pop


reshape wide ene-dic, i(state_code  categoryid typeid subtypeid ) j(year)


forvalues i = 1997/2014 {
egen t1`i' = rowtotal (ene`i' feb`i' mar`i')
egen t2`i' = rowtotal (abr`i' may`i' jun`i')
egen t3`i' = rowtotal (jul`i' ago`i' sep`i')
egen t4`i' = rowtotal (oct`i' nov`i' dic`i')
}

forvalues i = 1997/2014 {
egen c1`i' = rowtotal (ene`i' feb`i' mar`i' abr`i')
egen c2`i' = rowtotal (may`i' jun`i' jul`i' ago`i')
egen c3`i' = rowtotal (sep`i' oct`i' nov`i' dic`i')
}

forvalues i = 1997/2014 {
egen s1`i' = rowtotal (ene`i' feb`i' mar`i' abr`i' may`i' jun`i')
egen s2`i' = rowtotal (jul`i' ago`i' sep`i' oct`i' nov`i' dic`i')
}

forvalues i = 1997/2014 {
egen a`i' = rowtotal (ene`i' feb`i' mar`i' abr`i' may`i' jun`i' jul`i' ago`i' sep`i' oct`i' nov`i' dic`i')
}

cd "$states"

save state_total.dta




export excel state_code - subtypeid a1997-a2014  using "$states/state_total.xlsx", sheet("anual") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - subtypeid ene1997-dic2014  using "$states/state_total.xlsx", sheet("mensual") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - subtypeid t11997-t42014  using "$states/state_total.xlsx", sheet("trimestral") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - subtypeid c11997-c32014 using "$states/state_total.xlsx", sheet("cuatrimestral") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - subtypeid s11997-s22014  using "$states/state_total.xlsx", sheet("semestral") sheetmodify cell(A1) firstrow(varlabels)



use "Files/Iestatalmensual.dta", clear

drop ene-dic pop


reshape wide tene-tdic, i(state_code  categoryid typeid subtypeid ) j(year)


forvalues i = 1997/2014 {
egen t_t1`i' = rowtotal (tene`i' tfeb`i' tmar`i')
egen t_t2`i' = rowtotal (tabr`i' tmay`i' tjun`i')
egen t_t3`i' = rowtotal (tjul`i' tago`i' 	tsep`i')
egen t_t4`i' = rowtotal (toct`i' tnov`i' tdic`i')
}

forvalues i = 1997/2014 {
egen t_c1`i' = rowtotal (tene`i' tfeb`i' tmar`i' tabr`i')
egen t_c2`i' = rowtotal (tmay`i' tjun`i' tjul`i' tago`i')
egen t_c3`i' = rowtotal (tsep`i' toct`i' tnov`i' tdic`i')
}

forvalues i = 1997/2014 {
egen t_s1`i' = rowtotal (tene`i' tfeb`i' tmar`i' tabr`i' tmay`i' tjun`i')
egen t_s2`i' = rowtotal (tjul`i' tago`i' tsep`i' toct`i' tnov`i' tdic`i')
}

forvalues i = 1997/2014 {
egen t_a`i' = rowtotal (tene`i' tfeb`i' tmar`i' tabr`i' tmay`i' tjun`i' tjul`i' tago`i' tsep`i' toct`i' tnov`i' tdic`i')
}


save state_rate.dta


export excel state_code - subtypeid t_a1997-t_a2014  using "$states/state_rate.xlsx", sheet("anual") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - subtypeid tene1997-tdic2014  using "$states/state_rate.xlsx", sheet("mensual") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - subtypeid t_t11997-t_t42014  using "$states/state_rate.xlsx", sheet("trimestral") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - subtypeid t_c11997-t_c32014 using "$states/state_rate.xlsx", sheet("cuatrimestral") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - subtypeid t_s11997-t_s22014  using "$states/state_rate.xlsx", sheet("semestral") sheetmodify cell(A1) firstrow(varlabels)


cd Files

rm Iestatalmensual.dta
rm robo.dta
rm robototal.dta
rm roboviolenciatotal.dta
rm categorias.dta
rm total.dta
rm types.dta
rm statepop_nac.dta


*******+++++++++++++++++++++++++++++++Municipios*******
*Preparing population data base*
cd "$mun/Files"

clear
import delimited munpop.csv
drop if sex == "Males" | sex == "Females"
drop sex
drop if year > 2015 | year <2011
rename (population code) (pop mun_code)

save munpop.dta, replace



clear
set more off
cd "$mun/Files"
set excelxlsxlargefile on
import excel using "IncidenciaDelictivaMunicipal.xlsx", firstrow
drop if AO == .
save delitos-fuero-comun.dta, replace

**Erase leading, trailing and intermediate blank spaces in all string variables
replace  ENTIDAD = trim(itrim(ENTIDAD))
replace  MUNICIPIO = trim(itrim(MUNICIPIO))
replace  MODALIDAD = trim(itrim(MODALIDAD))
replace  TIPO = trim(itrim(TIPO))
replace  SUBTIPO = trim(itrim(SUBTIPO))

replace SUBTIPO ="CON ARMA DE FUEGO" if SUBTIPO == "POR ARMA DE FUEGO"
replace SUBTIPO ="CON ARMA BLANCA" if SUBTIPO == "POR ARMA BLANCA"


*Encoding codes*
encode ENTIDAD, gen(state_code) 
drop ENTIDAD 

*Renaming variables*
rename (INEGI MUNICIPIO AO MODALIDAD TIPO SUBTIPO ENERO* FEBRERO* MARZO* ABRIL* MAYO* JUNIO* ///
	JULIO* AGOSTO* SEPTIEMBRE* OCTUBRE* NOVIEMBRE* DICIEMBRE*)(mun_code municip year category ///
	type subtype ene* feb* mar* abr* may* jun* jul* ago* sep* oct* nov* dic*)



*Creating crime variable wich groups all categories of "ROBO" in just one*
gen crime = category
replace crime = "ROBO" if word(category,1) == "ROBO"

*Encoding crime, category, type and subtype
encode crime, gen(crimeid)
encode category, gen(categoryid)
encode type, gen(typeid)
encode subtype, gen(subtypeid)
label define categoryid 11 "ROBO TOTAL", add
label define categoryid 0"INCIDENCIA DELICTIVA", add
label define typeid 19 "TOTAL",add
label define subtypeid 30 "TOTAL",add

drop crime category type subtype

order state*  year *id 

destring ene-dic, replace


save Impalmensual.dta, replace


***Totales con o sin violencia por suptipo de robo (Con o sin violencia (typeid))***

*Robo comun**

keep if categoryid == 7 | categoryid == 9 | categoryid == 10

collapse (sum)  ene-dic , by(state_code mun_code municip year categoryid subtypeid)
gen typeid:typeid = 19

order state* mun* year category type subtype

save robo.dta, replace 




************


use Impalmensual.dta, clear

***Totales por tipo***
*Total de despojo, homicidio doloso, homicidio culposo, lesiones dolosas, culposas y robo comun con y sin violencia, robo a casa habitaciom
** con y sin violencia, robo a isnt bancarias con y sin violencia**

keep if typeid == 8 | categoryid == 3 | categoryid == 4| categoryid == 7 | categoryid == 9 | categoryid == 10

collapse (sum)  ene-dic  , by(state_code mun_code municip year categoryid typeid)
gen subtypeid:subtypeid = 30
order state* mun* year category type subtype

save types.dta, replace




******************
** totales por categoria***

use Impalmensual.dta, clear

drop if categoryid == 1 | categoryid == 2 |categoryid == 6 | categoryid == 8
collapse (sum)  ene-dic  , by(state_code mun_code municip year categoryid)

gen subtypeid:subtypeid = 30

gen typeid:typeid = 19

order state* mun* year category type subtype

save categorias.dta, replace

*** total robo **
use Impalmensual.dta, clear
keep if categoryid >6
collapse (sum)  ene-dic  , by(state_code mun_code municip year typeid)
gen dummy = 1 if typeid ==1 | typeid == 17
replace dummy = 2 if dummy == .
collapse (sum)  ene-dic  , by(state_code mun_code municip year dummy)
gen categoryid:categoryid = 11
gen typeid:typeid =4 if dummy == 2
replace typeid =17 if dummy ==1
gen subtypeid:subtypeid =30
drop dummy
save roboviolenciatotal.dta, replace
collapse (sum)  ene-dic  , by(state_code mun_code municip year categoryid subtypeid)
gen typeid:typeid =19
save robototal.dta, replace 


** total delitos**
 use Impalmensual.dta, clear
collapse (sum)  ene-dic  , by(state_code mun_code municip year)
gen categoryid:categoryid=0
gen typeid:typeid=19
gen subtypeid:subtypeid=30
save total.dta, replace

clear
append using "Impalmensual.dta" "robo.dta" "types.dta" "categorias.dta" "roboviolenciatotal.dta" "robototal.dta" "total.dta"

order state* mun* year category type subtype
sort mun_code  year category type subtype 

save Impalmensual.dta, replace


**tasas***

***REVISAR QUE HACER CON NO ESPECIFICADO Y OTROS MUNICIPIOS
merge m:1 year mun_code using munpop.dta
drop if year == 2015
drop if  _merge == 1 | _merge == 2
drop _merge 

save Impalmensual.dta, replace



**


drop pop
reshape wide ene-dic, i(state_code  municip crimeid categoryid typeid subtypeid  mun_code ) j(year)


*c‡lculos mensuales, triemstrlaes, etc***

forvalues i = 2011/2014 {
egen t1`i' = rowtotal (ene`i' feb`i' mar`i')
egen t2`i' = rowtotal (abr`i' may`i' jun`i')
egen t3`i' = rowtotal (jul`i' ago`i' sep`i')
egen t4`i' = rowtotal (oct`i' nov`i' dic`i')
}

forvalues i = 2011/2014 {
egen c1`i' = rowtotal (ene`i' feb`i' mar`i' abr`i')
egen c2`i' = rowtotal (may`i' jun`i' jul`i' ago`i')
egen c3`i' = rowtotal (sep`i' oct`i' nov`i' dic`i')
}

forvalues i = 2011/2014 {
egen s1`i' = rowtotal (ene`i' feb`i' mar`i' abr`i' may`i' jun`i')
egen s2`i' = rowtotal (jul`i' ago`i' sep`i' oct`i' nov`i' dic`i')
}

forvalues i = 2011/2014 {
egen a`i' = rowtotal (ene`i' feb`i' mar`i' abr`i' may`i' jun`i' jul`i' ago`i' sep`i' oct`i' nov`i' dic`i')
}

save "$mun/municip_total.dta", replace

export excel state_code - crimeid a2011-a2014  using "$mun/municip_total.xlsx", sheet("anual") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - crimeid ene2011-dic2014  using "$mun/municip_total.xlsx", sheet("mensual") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - crimeid t12011-t42014  using "$mun/municip_total.xlsx", sheet("trimestral") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - crimeid c12011-c32014  using "$mun/municip_total.xlsx", sheet("cuatrimestral") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - crimeid s12011-s22014  using "$mun/municip_total.xlsx", sheet("semestral") sheetmodify cell(A1) firstrow(varlabels)






use Impalmensual.dta, clear

foreach var of varlist ene-dic {
	gen t`var' = (`var' * 100000)/ pop
}


drop ene-dic pop

reshape wide tene-tdic, i(state_code  municip crimeid categoryid typeid subtypeid  mun_code ) j(year)



*c‡lculos mensuales, triemstrlaes, etc***

forvalues i = 2011/2014 {
egen t_t1`i' = rowtotal (tene`i' tfeb`i' tmar`i')
egen t_t2`i' = rowtotal (tabr`i' tmay`i' tjun`i')
egen t_t3`i' = rowtotal (tjul`i' tago`i' tsep`i')
egen t_t4`i' = rowtotal (toct`i' tnov`i' tdic`i')
}

forvalues i = 2011/2014 {
egen t_c1`i' = rowtotal (tene`i' tfeb`i' tmar`i' tabr`i')
egen t_c2`i' = rowtotal (tmay`i' tjun`i' tjul`i' tago`i')
egen t_c3`i' = rowtotal (tsep`i' toct`i' tnov`i' tdic`i')
}

forvalues i = 2011/2014 {
egen t_s1`i' = rowtotal (tene`i' tfeb`i' tmar`i' tabr`i' tmay`i' tjun`i')
egen t_s2`i' = rowtotal (tjul`i' tago`i' tsep`i' toct`i' tnov`i' tdic`i')
}

forvalues i = 2011/2014 {
egen t_a`i' = rowtotal (tene`i' tfeb`i' tmar`i' tabr`i' tmay`i' tjun`i' tjul`i' tago`i' tsep`i' toct`i' tnov`i' tdic`i')
}


save "$mun/municip_rate.dta", replace

export excel state_code - crimeid t_a2011-t_a2014  using "$mun/municip_rate.xlsx", sheet("anual") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - crimeid tene2011-tdic2014  using "$mun/municip_rate.xlsx", sheet("mensual") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - crimeid t_t12011-t_t42014  using "$mun/municip_rate.xlsx", sheet("trimestral") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - crimeid t_c12011-t_c32014  using "$mun/municip_rate.xlsx", sheet("cuatrimestral") sheetmodify cell(A1) firstrow(varlabels)
export excel state_code - crimeid t_s12011-t_s22014  using "$mun/municip_rate.xlsx", sheet("semestral") sheetmodify cell(A1) firstrow(varlabels)









****** Zonas Metropolitanas***************************************************

clear



use "$rates/Metro Zones/Files/MaestroCodigosMunicipios.dta"
keep mun_code am
save "$mun/Files/codigos_zm.dta", replace


use "Impalmensual.dta", clear
merge m:m mun_code using codigos_zm.dta

drop if am == .
drop _merge

order state_code  mun_code municip am categoryid typeid subtypeid crimeid

collapse (sum) ene-pop, by(am categoryid typeid subtypeid crimeid year)

save Izmmensual.dta, replace


drop pop
reshape wide ene-dic, i(am  crimeid categoryid typeid subtypeid  ) j(year)

*c‡lculos mensuales, triemstrlaes, etc***

forvalues i = 2011/2014 {
egen t1`i' = rowtotal (ene`i' feb`i' mar`i')
egen t2`i' = rowtotal (abr`i' may`i' jun`i')
egen t3`i' = rowtotal (jul`i' ago`i' sep`i')
egen t4`i' = rowtotal (oct`i' nov`i' dic`i')
}

forvalues i = 2011/2014 {
egen c1`i' = rowtotal (ene`i' feb`i' mar`i' abr`i')
egen c2`i' = rowtotal (may`i' jun`i' jul`i' ago`i')
egen c3`i' = rowtotal (sep`i' oct`i' nov`i' dic`i')
}

forvalues i = 2011/2014 {
egen s1`i' = rowtotal (ene`i' feb`i' mar`i' abr`i' may`i' jun`i')
egen s2`i' = rowtotal (jul`i' ago`i' sep`i' oct`i' nov`i' dic`i')
}

forvalues i = 2011/2014 {
egen a`i' = rowtotal (ene`i' feb`i' mar`i' abr`i' may`i' jun`i' jul`i' ago`i' sep`i' oct`i' nov`i' dic`i')
}


save "$mun/zm_total.dta", replace

use Izmmensual.dta,clear

foreach var of varlist ene-dic {
	gen t`var' = (`var' * 100000)/ pop
}


drop ene-dic pop

reshape wide tene-tdic, i(am   crimeid categoryid typeid subtypeid   ) j(year)



*c‡lculos mensuales, triemstrlaes, etc***

forvalues i = 2011/2014 {
egen t_t1`i' = rowtotal (tene`i' tfeb`i' tmar`i')
egen t_t2`i' = rowtotal (tabr`i' tmay`i' tjun`i')
egen t_t3`i' = rowtotal (tjul`i' tago`i' tsep`i')
egen t_t4`i' = rowtotal (toct`i' tnov`i' tdic`i')
}

forvalues i = 2011/2014 {
egen t_c1`i' = rowtotal (tene`i' tfeb`i' tmar`i' tabr`i')
egen t_c2`i' = rowtotal (tmay`i' tjun`i' tjul`i' tago`i')
egen t_c3`i' = rowtotal (tsep`i' toct`i' tnov`i' tdic`i')
}

forvalues i = 2011/2014 {
egen t_s1`i' = rowtotal (tene`i' tfeb`i' tmar`i' tabr`i' tmay`i' tjun`i')
egen t_s2`i' = rowtotal (tjul`i' tago`i' tsep`i' toct`i' tnov`i' tdic`i')
}

forvalues i = 2011/2014 {
egen t_a`i' = rowtotal (tene`i' tfeb`i' tmar`i' tabr`i' tmay`i' tjun`i' tjul`i' tago`i' tsep`i' toct`i' tnov`i' tdic`i')
}


save "$mun/zm_rate.dta", replace

************



rm Impalmensual.dta
rm robo.dta
rm robototal.dta
rm roboviolenciatotal.dta
rm categorias.dta
rm total.dta
rm types.dta




log close
