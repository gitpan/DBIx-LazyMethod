package DBIx::LazyMethod;

#DBIx::LazyMethod for the lazy hest $Id: LazyMethod.pm,v 1.2 2003/08/05 18:55:08 cwg Exp $
#Lazy DBI encapsulation for simple DB handling

use 5.005;
use strict;
use Carp;
use DBI;
use Exporter;
use vars qw($VERSION $AUTOLOAD @EXPORT @ISA);
use Data::Dumper; #for dev

use constant RETURN_VALUES => qw(WANT_ARRAY WANT_ARRAYREF WANT_HASHREF WANT_ARRAY_HASHREF WANT_RETURN_VALUE WANT_AUTO_INCREMENT); #The return value names
@EXPORT 	= RETURN_VALUES; 
@ISA    	= qw(Exporter);
$VERSION 	= do { my @r=(q$Revision: 1.2 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };
my $PACKAGE 	= "[DBIx::LazyMethod]";

#Public exported constants
use constant WANT_ARRAY 		=> 1;
use constant WANT_ARRAYREF 		=> 2;
use constant WANT_HASHREF 		=> 3;
use constant WANT_ARRAY_HASHREF 	=> 4;
use constant WANT_RETURN_VALUE 		=> 5;
use constant WANT_AUTO_INCREMENT 	=> 6;
use constant WANT_METHODS 		=> (WANT_ARRAY,WANT_ARRAYREF,WANT_HASHREF,WANT_ARRAY_HASHREF,WANT_RETURN_VALUE,WANT_AUTO_INCREMENT); #The return values

#Private constants
use constant TRUE 			=> 1;
use constant FALSE 			=> 0;
use constant PRIVATE_METHODS 		=> qw(new AUTOLOAD DESTROY connect disconnect error is_error);

#debug constant
use constant DEBUG 			=> 0;


=head1 NAME

DBIx::LazyMethod - Simple 'database query-to-accessor method' wrapper. Fast OO interface to your dataset.

=head1 SYNOPSIS

When used directly:

  use DBIx::LazyMethod;

  my %methods = (
	set_people_name_by_id => {
		sql => "UPDATE people SET name = ? WHERE id = ?",
		args => [ qw(name id) ],
		ret => WANT_RETURN_VALUE,
	},
	get_people_entry_by_id => {
		sql => "SELECT * FROM people WHERE id = ?",
		args => [ qw(id) ],
		ret => WANT_HASHREF,
	},
  );

  #set up the above methods on a Oracle database accessible through a DBI proxy 
  my $db = DBIx::LazyMethod->new(
		data_source  => "DBI:Proxy:hostname=192.168.1.1;port=7015;dsn=DBI:Oracle:PERSONS",
                user => 'user',
                pass => 'pass',
                attr => { 'RaiseError' => 0, 'AutoCommit' => 1 },
                methods => \%methods,  
                );
  if ($db->is_error) { die $db->{errormessage}; }

 Accessor methods are now available:
 
  my $rv = $db->set_people_name_by_id(name=>'Arne Raket', id=>42);
  if ($db->is_error) { die $db->{errormessage}; }

When sub-classed:

  use MyDB;	# Class inheriting everything from DBIx::LazyMethod except for 
		# the C<new> method - which is just a call to DBIx::LazyMethod 
		# with appropriate arguments - returning a DBIx::LazyMethods 
		# object. See lib/SomeDB.pm for an example.

  my $db = MyDB->new() or die;
 
 Accessor methods are now available:

  my $entry_ref = $db->get_people_entry_by_id(id=>42);

=head1 DESCRIPTION

A Lazy (and easily replaceable) DB abstraction layer.
In no way a new approach, rather an easy one.

=head2 What does that mean?

DBIx::LazyMethod uses AUTOLOAD to create methods and statement handles based on the 
data in the hashref supplied in the argument 'methods'.
Statement handles should be persistent in the lifetime of the instance.
It is an easy way to set up accessor methods for a fixed (in the sense of
database and table layout) data set.

When the DBIx::LazyMethod object is created, it is verified, for each method in the 
'methods' hashref, that the amount of required arguments
matches the amount of placeholders in the SQL (C<"?">). 

When a method defined in the 'methods' hashref is invoked, it is verified that the arguments
in 'args' are provided. The arguments are then applied to the persistent
statement handle (eg. _sth_set_people_name_by_id) that is created from the value 'sql' 
statement.

If the 'args' start with 'limit_' they are handled specially to enable placeholders
for 'LIMIT X,Y' (MySQL) syntax - if mysql DBD is used.

=head2 Why did you do that?

I was annoyed by the fact that I had to create virtually similar DB packages time and time again.
DBIx::LazyMethod started out as an experiment in how generic a (simple) DB module could be made. 
In many situations you would probably want to create a specialized DB package - but this one should get you started, without you having to change your interfaces at a later point.
Besides that. I'm just lazy.

=head1 KEYS IN METHODS DEFINITION

The 'args', 'sql' and 'ret' are mandatory arguments to each defined method.

=head2 args 

The value of 'args' is an array of key names. The keys must be in the same order as the mathing SQL placeholders ("?").
When the object is created, it is checked that the amount of keys match the amount of SQL placeholders.

=head2 sql

The 'sql' key holds the string value of the fixed SQL syntax. 

=head2 ret 

The value of 'ret' (return value) can be:

=over 4

=item *
	WANT_ARRAY returns in array context (SELECT)

=item *
	WANT_ARRAYREF returns a reference to an array (SELECT)

=item *
	WANT_HASHREF returns a reference to a hash (SELECT)

=item *
	WANT_ARRAY_HASHREF returns an array of hashrefs (SELECT)

=item *
	WANT_RETURN_VALUE returns the DBI returnvalue (NON-SELECT)

=item *
	WANT_AUTO_INCREMENT returns the new auto_increment value of an INSERT (MySQL specific).


=head1 CLASS METHODS

The following methods are available from DBIx::LazyMethod objects.  Any
function or method not documented should be considered private.  If
you call it, your code may break someday and it will be B<your> fault.

The methods follow the Perl tradition of returning false values when
an error occurs (and usually setting $@ with a descriptive error
message).

Any method which takes an SQL query string can also be passed bind
values for any placeholders in the query string:

=item C<new()>

The C<new()> constructor creates and returns a database connection
object through which all database actions are conducted. On error, it
will call C<die()>, so you may want to C<eval {...}> the call.  The
C<NoAbort> option (described below) controls that behavior.

C<new()> accepts ``hash-style'' key/value pairs as arguments.  The
arguments which it recognizes are:

=over 4

=item C<data_source>

The data source normally fed to DBI->connect. Normally in the format of 
C<dbi:DriverName:database_name>.

=item C<user>

The database connection username. 

=item C<pass>

The database connection password. 

=item C<attr>

The database connection attributes. Leave blank for DBI defaults.

=item C<methods>

The methods hash reference. Also see the KEYS IN METHODS DEFINITION description.

=back

=cut


sub new {
	my $class = shift;
	my %args = @_;
	my $self = bless {}, ref $class || $class;

	#did we get methods?
	my $methods_ref = $args{'methods'};
	unless (ref $methods_ref eq 'HASH') {
		die "$PACKAGE invalid methods definition: argument methods must be hashref";
	}
	#anything in it?
	unless (keys %$methods_ref > 0) {
		die "$PACKAGE no methods in methods hash";
	}
	#lets check the stuff
	my ($dbd_name) = $args{'data_source'} =~ /^dbi:(.*?):/i; 
	#this approach will have to change when we start to accept an already create DBI handle
	my $good_methods = 0;
	foreach my $meth (keys %$methods_ref) {
		#check for internal names / reserwed words in method names
		if (grep { $meth eq $_ } PRIVATE_METHODS) {
			die "$PACKAGE method name $meth is a reserved method name";
		}
		#A way to validate SQL could be nice.
		unless (defined ${%$methods_ref}{$meth}->{sql}) {
			die "$PACKAGE method $meth: missing SQL";
		}
		unless (defined ${%$methods_ref}{$meth}->{args}) {
			die "$PACKAGE method $meth: missing argument definition";
		}
		unless (defined ${%$methods_ref}{$meth}->{ret}) {
			die "$PACKAGE method $meth: missing return data definition";
		}
		unless (ref ${%$methods_ref}{$meth}->{args} eq 'ARRAY') {
			die "$PACKAGE method $meth: bad argument list";
		}

		#check if we got the right amout of args - Cleanup on isle 9!
		my $arg_count = @{${%$methods_ref}{$meth}->{args}};
		#we should probably rather get amount of placeholders from DBI at some point. But then we can't do it before a prepare.
		my @placeholders = ${%$methods_ref}{$meth}->{sql} =~ m/\?/g;

		unless ($arg_count == scalar @placeholders) {
			warn "$PACKAGE method $meth: argument list does not match number of placeholders in SQL. You should get an error from DBI.";
		}

		#check DBD specific issues
		if (${%$methods_ref}{$meth}->{ret} eq WANT_AUTO_INCREMENT) {
			unless (lc $dbd_name eq 'mysql') {
				die "$PACKAGE return value type WANT_AUTO_INCREMENT not supported by $dbd_name DBD in method $meth";
			}
		}

		unless (grep { ${%$methods_ref}{$meth}->{ret} eq $_ } WANT_METHODS ) {
			die "$PACKAGE bad return value definition in method $meth";
		}
		$good_methods++;
	}
	unless ($good_methods > 0) {
		die "$PACKAGE no usable methods in methods hashref";
	}

	#TODO: more input checking?
	#At some point an existing $dbh object could be passed as an argument to new() instead of this.
	$self->{'methods'} 		= $methods_ref;		
	$self->{'_data_source'} 	= $args{'data_source'} 	|| die "Argument data_source missing";
	$self->{'_user'} 		= $args{'user'} 		|| "";
	$self->{'_pass'}  		= $args{'pass'} 		|| undef; 
	$self->{'_attr'} 		= $args{'attr'} 		|| undef;
	#connect us
	$self->{'_dbh'} 		= $self->connect;
	
	return $self;
}

sub AUTOLOAD {
	my $self = shift;
	my %args = @_;
	my ($meth) = $AUTOLOAD =~ /.*::([\w_]+)/;

	#clear the error register
	$self->error(FALSE);

	#is it a DBI statement handle
        if ($AUTOLOAD =~ /.*::_sth_([\w_]+)/) {

                #unless it is already created 
                return if defined $self->{'_sth_'.$1};

		#we need a DBI handle
                #exists $self->{_dbh} or return $self->error("DBI handle missing");
		unless (exists $self->{_dbh} && ref $self->{_dbh} eq 'DBI::db') { return $self->error("DBI handle missing"); }

		#and a matching method
                exists $self->{'methods'}{$1} or $self->error("Method ".$1." not defined");

		#check special method and dbd bindings
		#unless (($self->{'methods'}{$1} eq 'mysql') && ($self->{_dbh}->{Driver}->{Name} eq 'mysql')) {
                #	die "You cannot use exists $self->{'methods'}{$1} or $self->error("Method ".$1." not defined");

		#we create a new DBI statement handle
                #my $dbh = $self->{_dbh};
		print STDERR "$PACKAGE DEBUG: preparing ".$self->{'methods'}{$1}->{sql}."\n" if DEBUG;
                $self->{'_sth_'.$1} =  $self->{_dbh}->prepare($self->{'methods'}{$1}->{sql}) or return $self->error($meth." prepare failed");
                return;
	}
	#is it a method
	elsif (defined $self->{'methods'}{$meth}) {
		
		#call the associated DBI statement handle (which is then automagically created)
		my $sthname = "_sth_".$meth;
		$self->$sthname();
	
		#and it the statement handle will appear on the self object
		my $sth = $self->{"_sth_".$meth};
		print STDERR "$PACKAGE DEBUG: Dumping self->methods->".$meth."->args\n" if DEBUG;
		print STDERR Dumper $self->{'methods'}{$meth}->{args} if DEBUG;
		my ($argsref) = $self->{'methods'}{$meth}->{args};
		#put the required bind values here
		my @bind_values = ();
		my $cnt = 1;
		#run through the args defined for the method
		foreach (@$argsref) {
			unless (defined $args{$_}) { 
				return $self->error($meth." Insufficient parameters (".$_.")");
			}
			#the argument was provided, so we use it
			push @bind_values, $args{$_};
			#for checking argument count later
			delete $args{$_};
			#puha hack for placeholders til MySQL limit syntax
			next unless ($self->{_dbh}->{Driver}->{Name} eq 'mysql');
			if ($_ =~ /^limit_/) { $self->{"_sth_".$meth}->bind_param($cnt,'',DBI::SQL_INTEGER); }
			$cnt++;
		}

		#warn if more arguments than needed was provided
		foreach (keys %args) {
			warn "$PACKAGE WARN: useless argument \"".$_."\" provided for method \"".$meth."\"";
		}

		#do it
		my $rv = $sth->execute(@bind_values) or return $self->error("_sth_".$meth." execute failed : ".DBI::errstr);
		print STDERR "$PACKAGE DEBUG: $meth DBI: ".DBI::errstr."\n" if (!$rv && DEBUG);
		unless ($rv) { return $self->error("DBI execute error: ".DBI::errstr); }

		my ($ret) = $self->{'methods'}{$meth}->{ret};
		print STDERR "Found ret for $meth: $ret\n" if DEBUG;

		if ($self->{'methods'}{$meth}->{ret} == WANT_ARRAY) {
			my @ret;
			while (my (@ref) = $sth->fetchrow_array) { push @ret,@ref }
			return @ret;
		} elsif ($self->{'methods'}{$meth}->{ret} == WANT_ARRAYREF) {
			my $ret = $sth->fetchrow_arrayref;
			if (ref $ret eq 'ARRAY') {
				return $ret;
			} else {
				return $self->error("_sth_".$meth." is using is doing fetching on a non-SELECT statement");
			}
		} elsif ($self->{'methods'}{$meth}->{ret} == WANT_HASHREF) {
			my $ret = $sth->fetchrow_hashref;
			if (ref $ret eq 'HASH') {
				return $ret;
			}else {
				return $self->error("_sth_".$meth." is using is doing fetching on a non-SELECT statement");
			}
		} elsif ($self->{'methods'}{$meth}->{ret} == WANT_ARRAY_HASHREF) {
			my @ret;
			while (my $ref = $sth->fetchrow_hashref) {
				push @ret, $ref;
			}
			return \@ret;
		} elsif ($self->{'methods'}{$meth}->{ret} == WANT_AUTO_INCREMENT) {
			#MySQL hack :)
			if (defined $sth->{'mysql_insertid'}) { 
				return $sth->{'mysql_insertid'};
			} else {
				return $self->error("_sth_".$meth." is using MySQL specific AUTO_INCREMENT on non-MySQL DBD");
			}
		} elsif ($self->{'methods'}{$meth}->{ret} == WANT_RETURN_VALUE) {
			return $rv;
		} else {
			return $self->error("No such return type for ".$meth);
		}

        } else {
                return $self->error("No such method: $AUTOLOAD");
        }
}

sub DESTROY ($) {
	my $self = shift;
	#do we have any methods?
	if (defined $self->{'methods'}) {
		#remember to bury statement handles
		foreach (keys %{$self->{'methods'}}) {
			#if the sth of a methods is defined it has been used
        	        if (defined $self->{'_sth_'.$_}) {
				#finish the sth
                	        $self->{'_sth_'.$_}->finish;
               		        print STDERR "$PACKAGE DEBUG: meth DESTROY - finished _sth_".$_." handle" if DEBUG;
               	 	}
		}
	}
	#and hang up if we have a connection
        if (defined $self->{'_dbh'}) { $self->disconnect(); }
}

sub connect {
        my $self = shift;

	my $data_source =	$self->{'_data_source'};
        my $user 	= 	$self->{'_user'};
        my $auth  	= 	$self->{'_pass'};
        my $attr  	= 	$self->{'_attr'};

	#$dbh = DBI->connect($data_source, $username, $auth, \%attr);

	#TODO: validate args
	if (defined $attr) {
		unless ((ref $attr) eq 'HASH') { die "argument 'attr' must be hashref"; }
	}

	print STDERR "$PACKAGE DEBUG: DBIx::LazyMethod doing: DBI->connect($data_source, $user, $auth, $attr);\n" if DEBUG;
	my $dbh  = DBI->connect($data_source, $user, $auth, $attr) or return $self->error("Connection failure [".DBI::errstr."]");
	return $dbh;
}

sub disconnect {
        my $self = shift;
        my $dbh = $self->{'_dbh'};

        unless (defined $dbh) { return 1 }

        if (!$dbh->disconnect) {
                $self->error("Disconnect failed [".DBI::errstr."]");
        } else {
		print STDERR "$PACKAGE DEBUG: Disconnected dbh\n" if DEBUG;
        }
	return 1;
}

sub error {
        my ($self,$data) = (shift,shift);
	if ($data eq FALSE) {
        	delete $self->{'errorstate'};
       		$self->{'errormessage'} = "[unknown]";
	} else {
        	$self->{'errorstate'} = TRUE;
        	$self->{'errormessage'} = $data;
        	warn "$PACKAGE ERROR: ".$data;
	}
        return;
}

sub is_error ($) {
	my $self = shift;
	return (defined $self->{'errorstate'})?TRUE:FALSE;
}

1;

=head1 COPYRIGHT

Copyright (c) 2002-03 Casper Warming <cwg@usr.bin.dk>.  All rights
reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Artistic License for more details.

=head1 AUTHOR

Casper Warming <cwg@usr.bin.dk>

=head1 TODO

More DBD specific functions (Oracle).

Better documentation.

More "failure" tests.

Testing expired statement handles.

=head1 ACKNOWLEDGEMENTS

Copenhagen Perl Mongers for the motivation. 
Sorry to Thomas Eibner for not naming the module Doven::Hest.

=head1 SEE ALSO

DBIx::DWIW

DBIx::Class

Class::Accessor

DBI(1).

=cut
