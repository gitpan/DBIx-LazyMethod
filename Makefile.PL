use ExtUtils::MakeMaker;

# $Id: Makefile.PL,v 1.1.1.1 2003/08/05 18:29:11 cwg Exp $

WriteMakefile(
    'NAME'	        => 'DBIx::LazyMethod',
    'VERSION_FROM'  => 'lib/DBIx/LazyMethod.pm', # finds $VERSION
	'PREREQ_PM' => {
		'POSIX'         => 0,
		'Test::Harness' => 0,
		'Test::More'    => 0,
		'DBI'    	=> 0,
		'Data::Dumper'  => 0,
	}
);
