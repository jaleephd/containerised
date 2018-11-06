#!/bin/bash
#
# This installs Ensembl-Vep post-installation of Ensembl.
# It depends on ensembl_install.sh, which installs the Ensembl API,
# database server/user/schemas and configures the environment.
#
# Author Justin Lee <justin.lee@jcu.edu.au>, 2018

# prior to running need to ensure that the following environment variables are set:
if [ -z "$ensembl_download_dir" ] || [ -z "$ensembl_install_dir" ]; then
    echo "these environment variables must be set prior to install: ensembl_download_dir ensembl_install_dir"
    exit 1
fi

if [ -z "$PERL5LIB" ]; then
    echo "PERL5LIB is not set! Please source/export the Ensembl Environment!"
    exit 1
fi

if [ -z "$ENSEMBL_REGISTRY" ]; then
    echo "ENSEMBL_REGISTRY is not set! Have you source/exported the Ensembl Environment?"
fi

# Ensembl URL, version and database schema-specific values
# ensembl_release# and GRCh# can be overriden in the environment
ensembl_base_url="ftp://ftp.ensembl.org/pub"
ensembl_vep_git_url="https://github.com/Ensembl/ensembl-vep.git"
ensembl_release="${ensembl_release:-93}"
release_ver="release-${ensembl_release}"
grch_build="${grch_build:-38}" # Genome Reference Consortium Human Build #
chrom_build="GRCh${grch_build}"
reference_chromosome="homo_sapiens_vep_${ensembl_release}_${chrom_build}"
cache_version="${ensembl_release}_${chrom_build}" 

# install VEP and VEP cache under $ensembl_install_dir
vep_install_dir=$ensembl_install_dir/ensembl-vep
vep_cache_dir=$ensembl_install_dir/ensembl-vep-cache

# convert offline cache for use with tabix
vep_convert_cache="${vep_convert_cache:-True}"

pushd . > /dev/null 2>&1
cd $ensembl_download_dir

# homo_sapiens_vep_93_GRCh38.tar.gz file is the manually downloaded VEP cache
# manually download (instead of doing with VEP installer using '--AUTO c') 
if [ ! -e $ensembl_download_dir/${reference_chromosome}.tar.gz ]; then
    echo "Downloading Homo Sapien reference chromsome from ${ensembl_base_url}/${release_ver}/variation/VEP/${reference_chromosome}.tar.gz ..."
    curl -O ${ensembl_base_url}/${release_ver}/variation/VEP/${reference_chromosome}.tar.gz 
    echo "Done!"
fi

# extract VEP cache
echo "cleaning/creating Ensembl-VEP cache directory $vep_cache_dir" 
[ -d $vep_cache_dir ] && rm -rf $vep_cache_dir
mkdir -p $vep_cache_dir
echo "extracting ${reference_chromosome}.tar.gz into Ensembl-vep cache directory..." 
tar xzf $ensembl_download_dir/${reference_chromosome}.tar.gz  -C $vep_cache_dir 
echo "Done!"

# download VEP
if [ ! -d $ensembl_download_dir/ensembl-vep ]; then
    echo "Downloading Ensembl-VEP..." 
    git clone $ensembl_vep_git_url
    if [ $? -ne 0 ]; then
        echo "Cloning of ensembl-vep from github failed!"
        exit 1
    fi
echo "Done!"
fi

# install VEP (where we'll add to path)
echo "Copying Ensembl-VEP into $ensembl_install_dir/ensembl-vep..." 
[ -d $ensembl_install_dir/ensembl-vep ] && rm -rf $ensembl_install_dir/ensembl-vep
cp -a $ensembl_download_dir/ensembl-vep $ensembl_install_dir/
echo "Done!"

# install VEP with options
# -l: Bio::DB::HTS/htslib modules,
# -f: homosapiens fasta file
# -p: plugins (all)
# NOTE that DESTDIR  specifies where HTS binary and Perl libs go
#           CACHEDIR specifies where modules and cache files go   
echo "Running Ensembl-VEP installer with:"
echo "perl INSTALL.pl --AUTO lfp --SPECIES homo_sapiens --ASSEMBLY $chrom_build --PLUGINS all --DESTDIR $vep_install_dir/HTS --CACHEDIR $vep_cache_dir"
cd $vep_install_dir
perl INSTALL.pl \
     --AUTO lfp \
     --SPECIES homo_sapiens --ASSEMBLY $chrom_build \
     --PLUGINS all \
     --DESTDIR $vep_install_dir/HTS \
     --CACHEDIR $vep_cache_dir

if [ $? -ne 0 ]; then
    echo "Ensembl-VEP: INSTALL.pl failed!"
    exit 1
fi
echo "Done!"

# add $vep_install_dir/HTS to PERL5LIB environment variable
export PERL5LIB="$PERL5LIB:$vep_install_dir/HTS"
# add $vep_install_dir/HTS/htslib to PATH environment variable
export PATH="$PATH:$vep_install_dir:$vep_install_dir/HTS/htslib"

# convert offline cache for use with tabix
# this significantly speeds up lookup of known variants:
if [ "$vep_convert_cache" = "True" ]; then
    echo
    echo "Converting offline cache for use with tabix (this takes several hours!)..."
    echo perl convert_cache.pl --species homo_sapiens --version $cache_version --dir $vep_cache_dir
    perl convert_cache.pl --species homo_sapiens --version $cache_version --dir $vep_cache_dir 
    if [ $? -ne 0 ]; then
        echo "Ensembl-VEP: convert_cache.pl failed!"
        exit 1
    fi
    echo "Done!"
fi

popd > /dev/null 2>&1

# tests - adapted from VEP Tutorial
# https://asia.ensembl.org/info/docs/tools/vep/script/vep_tutorial.html
echo
echo "Running post-install test:"
echo "vep --dir $vep_cache_dir -i $vep_install_dir/examples/homo_sapiens_${chrom_build}.vcf --cache --force_overwrite --sift b -o variant_effect_test_output.txt"
vep --dir $vep_cache_dir -i $vep_install_dir/examples/homo_sapiens_${chrom_build}.vcf --cache --force_overwrite --sift b -o variant_effect_test_output.txt
if [ $? -ne 0 ]; then
    echo "Ensembl-VEP: vep (SIFT prediction) test failed!"
    exit 1
fi

echo "filter_vep -i variant_effect_test_output.txt -filter \"SIFT is deleterious\" | grep -v \"##\" | head -n5"
# Note: not using pipeline here to only test for errors in filter_vep
filter_vep -i variant_effect_test_output.txt -filter "SIFT is deleterious" > variant_effect_test_output.filtered.txt
if [ $? -ne 0 ]; then
    echo "Ensembl-VEP: filter_vep test failed!"
    exit 1
fi
cat variant_effect_test_output.filtered.txt | grep -v "##" | head -n 5
rm -f variant_effect_test_output.filtered.txt 
echo "Done!"

echo
echo "Ensembl-VEP installation complete!"
echo
echo "Note that vep must be run with the cache directory specified:"
echo "     vep --dir $vep_cache_dir ..."
echo
echo "Please add the following to your environment:"
echo "PERL5LIB=\"\$PERL5LIB:$vep_install_dir/HTS\""
echo "PATH=\"\$PATH:$vep_install_dir:$vep_install_dir/HTS/htslib\""
echo

