#!/usr/bin/env python
import os
import os.path
import logging
import subprocess

def main( config):

	# set up directory
	sca_wd=config["main"]["wd"] + "/MODIS/SC"
	if not os.path.exists(sca_wd):
		os.makedirs(sca_wd)

	# # compute from dem of small grid
	# from getERA import getExtent as ext
	# latN = ext.main(gridpath + "/predictors/ele.tif" , "latN")
	# latS = ext.main(gridpath + "/predictors/ele.tif" , "latS")
	# lonW = ext.main(gridpath + "/predictors/ele.tif" , "lonW")
	# lonE = ext.main(gridpath + "/predictors/ele.tif" , "lonE")

	# call bash script that does grep type stuff to update values in options file
	# cmd = ["./DA/updateOptions.sh" , lonW , latS , lonE , latN , config["main"]["startDate"] , config["main"]["endDate"] , config["modis"]["options_file_SCA"], sca_wd, config['modis']['tileX_start'] , config['modis']['tileX_end'] , config['modis']['tileY_start'] , config['modis']['tileY_end']]
	cmd = ["./DA/updateOptions.sh" , config["main"]["startDate"] , config["main"]["endDate"] , config["modis"]["options_file_SCA"], sca_wd]

	subprocess.check_output( cmd)

	# run MODIStsp tool	
	from DA import getMODIS as gmod
	gmod.main("FALSE" , config["modis"]["options_file_SCA"], config["main"]["shp"] ) #  able to run non-interactively now




# calling main
if __name__ == '__main__':
	import sys
	config      = sys.argv[1]
	main( config)