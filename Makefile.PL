use ExtUtils::MakeMaker;
use Config;

WriteMakefile(
    'NAME'          => 'Term::Report',
    'DISTNAME'      => 'Term-Report',
    'VERSION_FROM'  => 'lib/Term/Report.pm',
    'AUTHOR'        => 'Shay Harding <sharding@ccbill.com>',
    'ABSTRACT'      => 'Command line reporting interface',
    'PREREQ_PM'     => {
							"Term::ANSIScreen"	=> '1.2',
							"Number::Format"	=> '1.44',
							"Term::StatusBar"	=> '1.0',
					   },
    'DEFINE'        => '',
    'INC'           => '',
    'dist'          => { COMPRESS => "gzip -9", SUFFIX => "gz" }
);
