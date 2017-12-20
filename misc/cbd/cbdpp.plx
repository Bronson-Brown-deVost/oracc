#!/usr/bin/perl
use warnings; use strict; use open 'utf8'; use utf8;
binmode STDIN, ':utf8'; binmode STDOUT, ':utf8'; binmode STDERR, ':utf8';
use Data::Dumper;
use lib "$ENV{'ORACC'}/lib";
use ORACC::CBD::ATF;
use ORACC::CBD::PPWarn;
use ORACC::CBD::SuxNorm;

use Getopt::Long;

my $bare = 0; # no need for a header
my $dry = 0; # no output files
my $filter = 0; # read from STDIN, write to CBD result to STDOUT
my $trace = 0;
my $vfields = '';

GetOptions(
    'bare'=>\$bare,
    'dry'=>\$dry,
    'filter'=>\$filter,
    'trace'=>\$trace,
    'validate:s'=>\$vfields,
    ) || die "unknown arg";

#GetOptions('f'=>\$filter); 
#print "filter=$filter\n"; exit 0;

$ORACC::CBD::PPWarn::trace = $trace;

my %validators = (
    entry=>\&v_entry,
    parts=>\&v_parts,
    bases=>\&v_bases,
    conts=>\&v_conts,
    prefs=>\&v_prefs,
    root =>\&v_root,
    form =>\&v_form,
    norms=>\&v_norms,
    sense=>\&v_sense,
    stems=>\&v_stems,
    bib=>\&v_bib,
    isslp=>\&v_isslp,
    equiv=>\&v_equiv,
    note=>\&v_note,
    inote=>\&v_inote,
    end=>\&v_end,
    project=>\&v_project,
    lang=>\&v_lang,
    name=>\&v_name,
    was=>\&v_deprecated,
    moved=>\&v_deprecated,
    bff=>\&v_bff,
    collo=>\&v_collo,
    geo=>\&v_geo,
    usage=>\&v_usage,
    );

my %rws_map = (
    EG => 'sux',
    ES => 'sux-x-emesal',
    CF => 'akk',
    CA => 'akk-x-conakk',
    OA => 'akk-x-oldass',
    OB => 'akk-x-oldbab',
    MA => 'akk-x-midass',
    MB => 'akk-x-midbab',
    NA => 'akk-x-neoass',
    NB => 'akk-x-neobab',
    SB => 'akk-x-stdbab',
    );

my $acd_chars = '->+=';
my $acd_rx = '['.$acd_chars.']';

my @funcs = qw/free impf perf Pl PlObj PlSubj Sg SgObj SgSubj/;
my %funcs = (); @funcs{@funcs} = ();

my @poss = qw/AJ AV N V DP IP PP CNJ J MA O QP RP DET PRP POS PRT PSP
    SBJ NP M MOD REL XP NU AN BN CN DN EN FN GN HN IN JN KN LN MN NN
    ON PN QN PNF RN SN TN U UN VN WN X XN YN ZN/; 

push @poss, ('V/t', 'V/i'); 
my %poss = (); @poss{@poss} = ();

my @stems = qw/B rr RR rR Rr rrr RRR rrrr RRRR S₁ S₂ S₃ S₄/;
my %stems = (); @stems{@stems} = ();

my @tags = qw/entry parts bff bases stems phon root form length norms
              sense equiv inote prop end isslp bib defn note pl_coord
              pl_id pl_uid was moved project lang name collo/;

my %tags = (); @tags{@tags} = ();

my @data = qw/usage collo sense/;

my %data = (); @data{@data} = ();

my %ppfunc = (
    usage=>\&pp_usage,
    collo=>\&pp_collo,
    sense=>\&pp_geo,
);

my $lng = '';
my $cbd = '';

unless ($filter) {
    $cbd = shift @ARGV;
    if ($cbd) {
	$lng = $cbd; $lng =~ s/\.glo$//; $lng =~ s#.*?/([^/]+)$#$1#;
    } else {
	die "cbdpp.plx: must give glossary on command line\n";
    }
} else {
    $cbd = '<stdin>';
}
pp_file($cbd);

my @acd = ();
my @cbd = ();
my @ngm = ();

my %bases = ();
my $bid = 0;
my $cbdlang = '';
my $in_entry = 0;
my $init_acd = 0;
my $is_compound = 0;
my $mixed_morph = 0;
my $project = '';
my $projdir = '';
my $seen_bases = 0;
my %seen_forms = ();
my $seen_morph2 = 0;
my $status = 0;
my %tag_lists = ();

my %vfields = ();
my %arg_vfields = (); 
if ($vfields) {
    @arg_vfields{split(/,/,$vfields)} = ();
    %vfields = %arg_vfields;
    @vfields{qw/lang entry end/} = ();
} else {
    %vfields = %tags;
    if ($trace) {
	%arg_vfields = %tags;
    }
}

###############################################################
#
# Program Body
#
###############################################################

pp_load();

# Allow files of bare glossary bits for testing
if ($bare) {
    $cbdlang = 'sux' unless $cbdlang;
    $project = 'test' unless $project;
}

die "cbdpp.plx: $cbd: can't continue without project and language\n"
    unless $project && $cbdlang;

if ($cbdlang =~ /sux|qpn/) {
    @cbd = ORACC::CBD::SuxNorm::normify($cbd, @cbd);
}

$projdir = "$ENV{'ORACC_BUILDS'}/$project";
pp_validate();

if ($status) {
    die("cbdpp.plx: errors in glossary $cbd. Stop.\n");
} else {    
    foreach my $f (keys %ppfunc) {
	if ($#{$data{$f}} >= 0) {
	    &{$ppfunc{$f}}();
	}
    }
}

atf_check($project,$cbdlang);

pp_cbd();

pp_diagnostics();

#######################################################################

sub pp_validate {
    for (my $i = 0; $i <= $#cbd; ++$i) {
	next if $cbd[$i] =~ /^\000$/ || $cbd[$i] =~ /^\#/;
	pp_line($i+1);
	if ($cbd[$i] =~ /^\s*$/) {
	    pp_warn("blank lines not allowed in \@entry")
		if $in_entry;
	} elsif ($cbd[$i] =~ /^\@([A-Z]+)\s*$/) {
	    my $rws = $1;
	    pp_warn("\@$1 unknown register/writing-system/dialect")
		unless $rws_map{$rws};
	    #	} elsif ($cbd[$i] =~ /^$acd_rx?@([a-z]+)\s+(.*)\s*$/o
	} elsif ($cbd[$i] =~ /@([a-z]+)/) {
	    my($tag,$line) = ($1,$2);
	    if (exists $tags{$tag}) {
		push @{$tag_lists{$tag}}, $i;
		if ($validators{$tag}) {
		    if (exists $vfields{$tag}) {
			if ($cbd[$i] =~ m/^(\S+)\s+(.*?)\s*$/) {
			    my($t,$l) = ($1,$2);
			    &{$validators{$tag}}($t,$l);
			} else {
			    &{$validators{$tag}}($cbd[$i],'');
			}
		    }
		} else {
		    pp_warn("internal error: no validator function defined for tag `$tag'");
		}
	    } else {
		pp_warn("\@$1 unknown tag");
	    }
	} else {
	    pp_warn("invalid line in glossary");
	}
    }
}

#################################################
#
#  VALIDATION
#
#################################################

sub v_project {
    my($line,$arg) = @_;
    return if $arg;
    if ($line =~ /\@project\s+(\S+)\s*$/) {
	$project = $1;
    } else {
	pp_warn("project empty or malformatted");
    }
};

sub v_lang {
    my($line,$arg) = @_;
    return if $arg;
    if ($line =~ /\@lang\s+(\S+)\s*$/) {
	$cbdlang = $1;
    } else {
	pp_warn("language empty or malformatted");
    }
};

sub v_name { 
    my($tag,$arg) = @_;
};

sub v_entry {
    my($tag,$arg) = @_;
    if ($trace && exists $arg_vfields{'entry'}) {
	pp_trace("v_entry: tag=$tag; arg=$arg\n");
    }
    my($pre,$etag,$pst) = ($tag =~ /^($acd_rx)?\@(\S+?)(\*?\!?)$/);
    my ($cf,$gw,$pos) = ();
    if ($etag && $etag eq 'entry') {
	$pre = '' unless $pre;
	$pst = '' unless $pst;
	if ($in_entry) {
	    if ($pre) {
		if ($in_entry > 1) {
		    pp_warn("multiple acd \@entry fields not permitted");
		} else {
		    push @{$data{'acd'}}, pp_line();
		}
	    } else {
		pp_warn("multiple \@entry fields not permitted");
	    }
	    ++$in_entry;
	} elsif ($in_entry > 1 ) {
	    pp_warn("max two \@entry fields allowed");
	} else {
	    ++$in_entry;
	    ($cf,$gw,$pos) = ($arg =~ /^([^\[]+)\s+(\[[^\]]+\])\s+(\S+)\s*$/);
	    if (!$cf) {
		if ($arg =~ /\[/ && $arg !~ /\s\[/) {
		    pp_warn("missing space before [ in CF [GW] POS");
		} elsif ($arg =~ /\]/ && $arg !~ /\]\s/) {
		    pp_warn("missing space after ] in CF [GW] POS");
		} elsif ($arg =~ /\]/ && $arg !~ /\]\s*$/) {
		    pp_warn("missing POS in CF [GW] POS");
		} else {
		    pp_warn("syntax error in \@entry's CF [GW] POS");
		}
	    } else {
		$is_compound = $cf =~ /\s/;
		pp_warn("unknown POS '$pos'") unless exists $poss{$pos};
	    }
	}
	if ($pre) {
	    v_acd_ok($pre);
	}
	if ($pst) {
	    if ($pst !~ /^\*|\!$/) {
		pp_warn("bad \@entry suffix: allowed sequences are '*', '!'");
	    }
	}
	if ($trace && exists $arg_vfields{'entry'}) {
	    $cf = '' unless $cf;
	    $gw = '' unless $gw;
	    $pos = '' unless $pos;
	    pp_trace "entry: cf=$cf; gw=$gw; pos=$pos; pre=$pre, pst=$pst\n";
	}
    } else {
	pp_warn("bad format in \@entry");
    }
}

sub v_acd_ok {
    my $pre = shift;
    if ($pre !~ /^$acd_rx$/) {
	pp_warn("(acd) only $acd_rx allowed");
    } else {
	if (length($pre) > 1) {
	    pp_warn("(acd) only one of $acd_rx allowed");
	}		 
    }
}

sub v_bases {
    my($tag,$arg) = @_;
    if ($trace && exists $arg_vfields{'bases'}) {
	pp_trace "v_bases: tag=$tag; arg=$arg\n";
    }
    my @bits = split(/;\s+/, $arg);
    if ($trace && exists $arg_vfields{'bases'}) {
	pp_trace "v_bases: \@bits=@bits\n";
    }

    if ($seen_bases++) {
	pp_warn("\@bases can only be given once");
	return;
    }
    
    my $alt = '';
    my $stem = '';
    my $pri = '';
    foreach my $b (@bits) {
	if ($b =~ s/^\*(\S+)\s+//) {
	    $stem = $1;
	} elsif ($b =~ /^\*/) {
	    $b =~ s/^\*\s*//;
	    pp_warn("misplaced '*' in \@bases");
	}
	if ($b =~ /\s+\(/) {
	    my $tmp = $b;
	    pp_warn("malformed alt-base in `$b'")
		if ($tmp =~ tr/()// % 2);
	    ($pri,$alt) = ($b =~ /^(\S+)\s+\((.*?)\)\s*$/);
	    if ($pri =~ s/>.*$//) {
		push @{$data{'acd'}}, pp_line();
	    }
	    if ($pri =~ /\s/) {
		pp_warn("space in base `$pri'")
	    } else {
		++$bases{$pri};
		$bases{$pri,'*'} = $stem
		    if $stem;
	    }
	    atf_add($pri);
	    foreach my $t (split(/,\s+/,$alt)) {
		if ($t =~ /\s/) {
		    pp_warn("space in alt-base `$t'");
		} else {
		    atf_add($t);
		}
	    }
	} else {
	    if ($b =~ /\s/) {
		pp_warn("space in base `$b'");
		$pri = $alt = '';
	    } else {
		++$bases{$b};
		$bases{$b,'*'} = $stem
		    if $stem;
		atf_add($b);
		$pri = $b;
		$alt = '';
	    }
	}
    }
    if ($trace && exists $arg_vfields{'bases'}) {
	pp_trace "v_bases: dump of \%bases:\n";
	pp_trace Dumper \%bases;
    }
}

sub v_form {
    my($tag,$arg) = @_;

    $arg = '' unless $arg;
    
    if ($trace) {
	pp_trace "v_form: tag=$tag; arg='$arg'; cbdlang=$cbdlang\n";
    }
    
    unless ($arg) {
	pp_warn("empty \@form");
	return;
    }
    if ($arg =~ /^[\%\$\#\@\+\/\*]/) {
	pp_warn("\@form must begin with writing of form");
	return;
    }
    
    my $barecheck = $arg;
    $barecheck =~ s/^(\S+)\s*//;
    my $formform = $1;
    atf_add($formform);

    if ($formform =~ /[áéíúàèìùÁÉÍÚÀÈÌÙ]/) {
	pp_warn("accented vowels not allowed in \@form");
    }

    if ($formform =~ /[<>]/) {
	pp_warn("angle brackets not allowed in \@form");
    }

    my $f = $arg;
    my $flang = '';
    if ($f =~ s/(?:^|\s+)\%(\S+)//) {
	$flang = $1;
	$f =~ s/^\s*//;
    } elsif ($cbdlang =~ /^qpn/) {
	pp_warn("no %LANG in QPN glossary \@form entry");
    }

    my($fo) = ($f =~ /^(\S+)/);
    if ($seen_forms{$fo,$flang}++) {
	pp_warn("duplicate form: $fo");
	return;
    }

    if ($fo =~ tr/_/ / && !$is_compound) {
	pp_warn("underscore (_) not allowed in form except in compounds");
    }
    
    if (($cbdlang =~ /^akk/ 
	 || ($cbdlang =~ /^qpn/ && $flang =~ /akk/))) {
	pp_warn("no normalization in form")
	    unless $f =~ m#(?:^|\s)\$\S#;
    }

    if (($cbdlang =~ /^sux/ 
	 || ($cbdlang =~ /^qpn/ && $flang =~ /sux/))
	&& !$is_compound) {
	pp_warn("no BASE entry in form")
	    unless $f =~ m#(?:^|\s)/\S#;
    }

    if ($f =~ /\s\+(\S+)/) {
	my $c = $1;
	pp_warn("malformed CONT '$c'")
	    unless $c =~ /^-(.*?)=(.*?)$/;
    }

    my $morph = '';
    if ($f =~ /\s\#([^\#]\S*)/) {
	$morph = $1;
    }
    if ($f =~ /\s\#\#(\S+)/) {
	++$seen_morph2;
	my $morph2 = $1;
	pp_warn("morph2 `$morph2' has no morph1")
	    unless $morph;
    } elsif ($morph && $seen_morph2) {
	if ($f =~ s/\s\#//g > 1) {
	    pp_warn("repeated `$morph' field (missing '#' on morph2?)");
	} else {
	    pp_warn("morph has no morph2")
		unless $mixed_morph;
	}
    }
    
    1 while $barecheck =~ s#(^|\s)[\%\$\#\@\+\/\*!]\S+#$1#g;

    if ($barecheck =~ /\S/) {
	pp_warn("bare word in \@form. barecheck=$barecheck; arg=$arg");
    } else {
	my $tmp = $arg;
	$tmp =~ s#\s/(\S+)##; # remove BASE because it may contain '$'s.
	$tmp =~ s/^\S+\s+//; # remove FORM because it may contain '$'s.
	my $ndoll = 0;
	if (($ndoll = ($tmp =~ tr/$/$/)) > 1 
	    && !$is_compound) {
	    my $nparen = ($tmp =~ s/\$\(//g);
	    pp_trace "v_form COF: ndoll=$ndoll; nparen=$nparen\n";
	    if ($ndoll - $nparen > 1) {
		pp_warn("COFs must have only one NORM without parens (found more than 1)");
	    } elsif ($ndoll == $nparen) {
		pp_warn("COFs must have one NORM without parens (found none)");
	    }
	}
    }
}

sub v_parts {
    my($tag,$arg) = @_;
    $_[0];
}

sub v_sense {
    my($tag,$arg) = @_;
#    if ($s =~ s/^(\S+)\s+//) {
#	$sid = $1;
#	if ($sid =~ s/!$//) {
#	    $defattr = ' default="yes"';
#	}
#	$sigs = $sigs{$sid};
#    }

    if ($arg =~ s/^\[(.*?)\]\s+//) {
#	$sgw = $1;
    }
    
    my($pre,$etag,$pst) = ($tag =~ /^($acd_rx)?\@(\S+?)(\!?)$/);

    if ($pre) {
	if ($cbd[pp_line()-1] =~ /^$acd_rx/) {
	    pp_warn("multiple acd \@sense fields in a row not permitted");
	} else {
	    push @{$data{'acd'}}, pp_line();
	}
    }
    
    my($pos,$mng) = ();
    if ($arg =~ /^[A-Z]+(?:\/[it])?\s/) {
	($pos,$mng) = ($arg =~ /^([A-Z]+(?:\/[it])?)\s+(.*)\s*$/);
    } else {
	$mng = $arg;
	$mng =~ s/^\s*(.*?)\s*$/$1/;
    }
    if ($pos) {
	if (!exists $poss{$pos} && $pos !~ /^V\/[ti]/) {
	    if ($pos =~ /^[A-Z]+$/) {
		pp_warn("$pos not in known POS list");
	    } else {
		$mng = "$pos $mng";
	    }
	}
    } else {
	$pos = '';
    }
    if (!$mng) {
	pp_warn("no content in SENSE");
	$mng = '';
    }

    if ($arg =~ tr/"//d) {
	pp_warn("double quotes not allowed in SENSE; use Unicode quotes instead");
    }
    if ($arg =~ tr/[]//d) {
	pp_warn("square brackets not allowed in SENSE; use Unicode U+27E6/U+27E7 instead");
    }
    if ($arg =~ tr/;//d) {
	pp_warn("semi-colons not allowed in SENSE; use comma or split into multiple SENSEs");
    }
    my($tok1) = ($arg =~ /^(\S+)/);
    if (!$tok1) {
	pp_warn("empty SENSE");
    } else {
	pp_warn("$tok1: unknown POS in SENSE") unless exists $poss{$tok1};
	pp_warn("no content in SENSE") unless $arg =~ /\s\S/;
    }
    
    $_[0];
}

sub v_bff {
    my($tag,$arg) = @_;
    my($class,$code,$label,$link,$target) = ();
    $arg =~ s/\s*$//;
    if ($arg =~ /^["<]/) {
	pp_warn("missing CLASS in \@bff");
	return {
	    curr_id=>pp_line()-1,
	    line=>$.,
	    link=>''
	};
    } else {
	($arg =~ s/^(\S+)\s*//) && ($class = $1);
#	unless ($bff_class{$class}) {
#	    pp_warn( "unknown bff CLASS: $class\n");
#	}
	if ($arg !~ /^["<]/) {
	    ($arg =~ s/^(\S+)\s*//) && ($code = $1);
	}
	if ($arg =~ /^"/) {
	    ($arg =~ s/^"(.*?)\"\s+//) && ($label = $1);
	}
	if ($arg =~ /<[^>]*$/) {
	    pp_warn("missing close '>' on bff link");
	    return;
	}
	if ($arg =~ /^[^<]*$/) {
	    pp_warn("missing open '<' on bff link");
	    return;
	}
	($arg =~ s/\s*<(.*?)>\s*$//) && ($link = $1);
	if ($arg) {
	    #	    pp_warn("bff is CLASS CODE \"LABEL\" <LINK> where CODE and \"LABEL\" are optional");
	    pp_warn("bff leftovers=$arg (out of order components?)");
	}
	return {
	    bid=>$bid++,
	    class=>$class,
	    code=>$code,
	    label=>$label,
	    link=>$link,
	    line=>pp_line(),
	    ref=>pp_line()-1,
	};
    }
}

sub v_bib {
    my($tag,$arg) = @_;
}

sub v_isslp {
    my($tag,$arg) = @_;
}

sub v_equiv {
    my($tag,$arg) = @_;
}

sub v_inote {
    my($tag,$arg) = @_;
}

sub v_note {
    my($tag,$arg) = @_;
}

sub v_root {
    my($tag,$arg) = @_;
}

sub v_norms {
    my($tag,$arg) = @_;
}

sub v_conts {
    my($tag,$arg) = @_;
}

sub v_prefs {
    my($tag,$arg) = @_;
}

sub v_collo {
    my($tag,$arg) = @_;
}

sub v_geos {
    my($tag,$arg) = @_;
}

sub v_usage {
    my($tag,$arg) = @_;
}

sub v_end {
    my($tag,$arg) = @_;
    pp_warn("malformed \@end entry")
	unless $arg =~ /^\s*entry\s*$/;
    $in_entry = $seen_bases = 0;
    %bases = ();
    %seen_forms = ();
}

sub v_deprecated {
    pp_warn("$_[0] is deprecated, please remove from glossary");
}

sub is_proper {
    $_[0] && $_[0] =~ /^[A-Z]N$/;
}

sub check_base {
    my($b,%b) = @_;
    my @b = keys %b;
    unless ($b{$b}) {
	bad('form', "unknown base `$b'");
	0;
    }
    1;
}

################################################
#
# Utility routines
#
################################################

sub pp_entry_of {
    my $i = shift;
    while ($cbd[$i] !~ /\@entry/) {
	--$i;
    }
    $i;
}

sub pp_load {
    if ($filter) {
	@cbd = (<>); chomp @cbd;
    } else {
	open(C,$cbd) || die "cbdpp.plx: unable to open $cbd. Stop.\n";
	@cbd = (<C>); chomp @cbd;
	close(C);
    }

    my $insert = -1;
    for (my $i = 0; $i <= $#cbd; ++$i) {
	if ($cbd[$i] =~ /^$acd_rx?\@([a-z]+)/) {
	    my $tag = $1;
	    if ($tag ne 'end') {
		if ($tag eq 'project') {
		    pp_line($i+1);
		    v_project($cbd[$i]);
		} elsif ($tag eq 'lang') {
		    pp_line($i+1);
		    v_lang($cbd[$i]);
		}
		$insert = $i;
		push(@{$data{$tag}}, $i) if exists $data{$tag};
	    } else {
		$insert = -1;
	    }
	} elsif ($cbd[$i] =~ s/^\s+(\S)/ $1/) {
	    if ($insert >= 0) {
		$cbd[$insert] .= $cbd[$i];
		$cbd[$i] = "\000";
	    } else {
		pp_warn("indented lines only allowed within \@entry");
	    }
	}
    }
}

################################################
#
# CBDPP Operational Functions
#
################################################

sub pp_acd {
    open(ACD, '>pp.acd');
    foreach my $i (@{$data{'acd'}}) {
	print ACD $cbd[$i], "\n";
	$cbd[$i] = "\000";
    }
    close(ACD);
}

sub pp_cbd {
    return if pp_status();
    if ($filter) {
	foreach (@cbd) {
	    print "$_\n" unless /^\000$/;
	}
    } else {
	my $ldir = "$projdir/01tmp";
	system 'mkdir', '-p', $ldir;
	open(CBD, ">$ldir/$cbdlang.glo") 
	    || die "cbdpp.plx: can't write to $ldir/$cbdlang.glo";
	foreach (@cbd) {
	    print CBD "$_\n" unless /^\000$/;
	}
	close(CBD);
    }
}
sub pp_collo {
    my $ndir = "$projdir/02pub";
    system 'mkdir', '-p', $ndir;
    open(COLLO, ">$ndir/coll-$cbdlang.ngm");
    foreach my $i (@{$data{'collo'}}) {
	my $e = pp_entry_of($i);
	my $c = $cbd[$e];
	$c =~ s/^\S*//;
	$c =~ s/\].*$/\]/;
	$c =~ s/\s+\[/\[/;
	my $cc = $cbd[$i];
	$cc =~ s/\s+-(\s+|$)/ $c /;
	$cc =~ s/\s+$//;
	$cc =~ s/^\S+\s+//;
	print COLLO $cc, "\n";
	$cbd[$i] = "\000";
    }
    close(COLLO);
}
sub pp_geo {
    open(GEOS, '>pp.geos') || die "cbdpp.plx: can't write to pp.glo";
    foreach my $i (@{$data{'geos'}}) {
	print GEOS $cbd[$i], "\n";
	$cbd[$i] = "\000";
    }
    close(GEOS);
}
sub pp_usage {
    open(USAGE,'>pp.usage');
    foreach my $i (@{$data{'collo'}}) {
	print USAGE $cbd[$i], "\n";
	$cbd[$i] = "\000";
    }
    close(USAGE);
}

1;
