#!/usr/bin/perl

  my $ver = "1.00";
  `./build_manifest.pl`;

  open FILE, "../MANIFEST";
  my $str;

  for (<FILE>){
      chomp;
      $str .= "./Term-Report-$ver/$_ ";
  }

  `tar -C ../.. -zcf Term-Report-$ver.tar.gz $str`;
  `mv Term-Report-$ver.tar.gz ../`;
  close FILE;
