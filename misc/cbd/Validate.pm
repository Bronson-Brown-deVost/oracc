package ORACC::CBD::Validate;
require Exporter;
@ISA=qw/Exporter/;

@EXPORT = qw/pp_validate v_project v_lang v_form v_is_entry v_set_cfgw/;

use warnings; use strict; use open 'utf8'; use utf8;

my @tags = qw/letter entry parts bff bases stems phon root form length norms
              sense equiv inote prop end isslp bib defn note pl_coord
              pl_id pl_uid was moved project lang name collo proplist prop/;

my %tags = (); @tags{@tags} = ();

my %validators = (
    letter=>\&v_letter,
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
    proplist=>\&v_proplist,
    prop=>\&v_prop,
    alias=>\&v_alias,
    pl_id=>\&v_pl_id,
    pl_uid=>\&v_pl_uid,
    pl_coord=>\&v_pl_coord
    );

use ORACC::L2GLO::Langcore;
use ORACC::CBD::ATF;
use ORACC::CBD::PPWarn;
use ORACC::CBD::Props;
use ORACC::SL::BaseC;
use Data::Dumper;

#################################################
#
#  VALIDATION
#
#################################################


my $acd_chars = '->+=';
my $acd_rx = '['.$acd_chars.']';

$ORACC::CBD::Edit::acd_rx = $acd_rx;

my @poss = qw/AJ AV N V DP IP PP CNJ J MA O QP RP DET PRP POS PRT PSP
    SBJ NP M MOD REL XP NU AN BN CN DN EN FN GN HN IN JN KN LN MN NN
    ON PN QN PNF RN SN TN U UN VN WN X XN YN ZN/; 

push @poss, ('V/t', 'V/i'); 
my %poss = (); @poss{@poss} = ();

my @geo_pos = qw/AN EN FN GN ON SN QN TN WN/;
my %geo_pos = (); @geo_pos{@geo_pos} = ();

my @stems = qw/B rr RR rR Rr rrr RRR rrrr RRRR S₁ S₂ S₃ S₄/;
my %stems = (); @stems{@stems} = ();

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

my @funcs = qw/free impf perf Pl PlObj PlSubj Sg SgObj SgSubj/;
my %funcs = (); @funcs{@funcs} = ();

my %vfields = ();
my %arg_vfields = ();

my %bases = ();
my $bid = 0;
my $curr_cfgw = '';
my @global_cbd = ();
my $in_entry = 0;
my $init_acd = 0;
my $is_compound = 0;
my $lang = '';
my $mixed_morph = 0;
my $project = '';
my $status = 0;
#my %tag_lists = ();
my %seen_entries = ();
my $seen_bases = 0;
my $seen_sense = 0;
my $seen_morph2 = 0;
my $trace = 0;
my $vfields = '';

sub init {
    my $vfields = shift;
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
}
my %data = ();

sub pp_validate {
    my($args,@cbd) = @_;
    %data = %ORACC::CBD::Util::data;
    $trace = $ORACC::CBD::PPWarn::trace;
    @global_cbd = @cbd;
    ($project,$lang,$vfields) = @$args{qw/project lang vfields/};
    init($vfields);

    ORACC::SL::BaseC::init();
    ORACC::SL::BaseC::pedantic();

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
	    my $tag = $1;
	    if (exists $tags{$tag}) {
#		push @{$tag_lists{$tag}}, $i;
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
    atf_check($project,$lang);
    cpd_check($project,$lang, $$args{'file'});
#    @{$$data_ref{'edit'}} = @{$data{'edit'}};
#    $data{'taglists'} = \%tag_lists;
    %ORACC::CBD::Util::data = %data;
}

sub v_project {
    my($line,$arg) = @_;
    return if $arg;
    my $proj = '';
    if ($line =~ /\@project\s+(\S+)\s*$/) {
	$proj = $1;
    } else {
	pp_warn("project empty or malformatted");
    }
    $proj;
}

sub v_lang {
    my($line,$arg) = @_;
    return if $arg;
    my $vlang = '';
    if ($line =~ /\@(?:qpnbase)?lang\s+(\S+)\s*$/) {
	$vlang = $1;
	if ($vlang =~ s/^\%//) {
	    pp_warn("language in header should not start with `%'");
	}
	unless (lang_known($vlang)) {
	    pp_warn("unknown language `$vlang' in header");
	    $vlang = '';
	}
	
    } else {
	pp_warn("language empty or malformatted");
    }
    $vlang;
}

sub v_name { 
    my($tag,$arg) = @_;
}

sub v_letter {
    my($tag,$arg) = @_;
}

sub v_entry {
    my($tag,$arg) = @_;
    if ($trace && exists $arg_vfields{'entry'}) {
	pp_trace("v_entry: tag=$tag; arg=$arg");
    }
    $seen_sense = 0;
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
		    push @{$data{'edit'}}, pp_line()-1;
		}
	    } else {
		pp_warn("multiple \@entry fields not permitted");
	    }
	    ++$in_entry;
	} elsif ($in_entry > 1) {
	    pp_warn("max two \@entry fields allowed");
	} else {
	    ++$in_entry;
	    $curr_cfgw = $arg;
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
		$is_compound = ($cf =~ /\s/);
		if (exists $poss{$pos}) {
		    if (exists $geo_pos{$pos}) {
			push @{$data{'geo'}}, pp_line()-1;
		    }
		} else {
		    pp_warn("unknown POS '$pos'");
		}
		my $ee = "$cf $gw $pos";
		if ($seen_entries{$ee}++) {
		    pp_warn("duplicate entry `$ee'");
		}
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
	    pp_trace "entry: cf=$cf; gw=$gw; pos=$pos; pre=$pre, pst=$pst";
	}
    } else {
	pp_warn("bad format in \@entry '$tag'. (acd=$acd_rx)");
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
	pp_trace "v_bases: tag=$tag; arg=$arg";
    }
    if ($arg =~ s/;\s*$//) {
	pp_warn("bases entry ends with semi-colon--please remove it");
    }
    my @bits = split(/;\s+/, $arg);
    if ($trace && exists $arg_vfields{'bases'}) {
	pp_trace "v_bases: \@bits=@bits";
    }

    if ($seen_bases++) {
	pp_warn("\@bases can only be given once");
	return;
    }

    my $alt = '';
    my $stem = '';
    my $pri = '';
    my %vbases = (); # this one is just for validation of the current @bases field
    my $pricode = 0;
    
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
	    ($pri,$alt) = ($b =~ /^(.*?)\s+\((.*?)\)\s*$/);
	    if ($pri) {
		if ($pri =~ s/>.*$//) {
		    push @{$data{'edit'}}, pp_line()-1;
		}
		if ($pri =~ /\s/ && !$is_compound) {
		    pp_warn("space in base `$pri'");
		    $pri = $alt = '';
		} else {
		    ++$bases{$pri};
		    $bases{$pri,'*'} = $stem
			if $stem;
		}
		if ($pri) {
		    if (defined $vbases{$pri}) {
			pp_warn("repeated base $pri");
		    } else {
			%{$vbases{$pri}} = ();
			$vbases{"$pri#code"} = ++$pricode;
		    }
		    foreach my $a (split(/,\s+/,$alt)) {
			if ($a =~ /\s/ && !$is_compound) {
			    pp_warn("space in alt-base `$a'");
			    $pri = $alt = '';
			} else {
			    if ($a) {
				if (${$vbases{$pri}}{$a}++) {
				    pp_warn("$pri has repeated alternate base $a");
				}
				# all alternates for this primary
				++${$vbases{"$pri#alt"}}{$a};
				$bases{"#$a"} = $pri;
				# all alternates in this @bases
				if (defined ${${$vbases{'#alt'}}{$a}}) {
				    my $prevpri =  ${${$vbases{'#alt'}}{$a}};
				    pp_warn("alt $a already defined for primary $prevpri\n");
				} else {
				    ${${$vbases{'#alt'}}{$a}} = $pri;
				}
			    }
			}
		    }
		}
	    } else {
		pp_warn("syntax error in base with (...) [missing paren?]");
	    }
	} else {
	    if ($b =~ /\s/ && !$is_compound) {
		pp_warn("space in base `$b'");
		$pri = $alt = '';
	    } else {
		++$bases{$b};
		$bases{$b,'*'} = $stem
		    if $stem;
		$pri = $b;
		$alt = '';
		if (defined $vbases{$pri}) {
		    pp_warn("repeated base $pri");
		} else {
		    %{$vbases{$pri}} = ();
		    $vbases{"$pri#code"} = ++$pricode;
		}
	    }
	}
    }

    # Now that we have all the primary and alternate bases syntactically validated
    # and captured in %vbases we can do some more validation ...

#    warn "second phase base checking\n";
    
    # 1. Does more than one primary have the same signs?
    my %prisigs = ();
    my %altsigs = ();
    foreach my $p (sort keys %vbases) {
	next if $p =~ /\#/;
	my $psig = ORACC::SL::BaseC::check(undef,$p);
	unless (pp_sl_messages($p)) {
	    if (defined $prisigs{$psig}) {
		pp_warn("(bases) primary bases '$p' and '$prisigs{$psig}' are the same");
	    } else {
#		warn "adding $psig to prisigs for $p\n";
		$prisigs{$psig} = $p;
		$prisigs{$p} = $psig;
	    }
	}
    }

    # 2. Does each alternate have the same signs as its primary?
    foreach my $p (sort keys %vbases) {
	next if $p =~ /\#/;
	my $prisig = $prisigs{$p}; # if this is empty there was an error earlier
	if ($prisig && defined $vbases{"$p#alt"}) {
	    my @alts = sort keys %{$vbases{"$p#alt"}};
	    my $pcode = $vbases{"$p#code"};
	    foreach my $a (@alts) {
		my $asig = ORACC::SL::BaseC::check(undef,$a);
		unless (pp_sl_messages()) {
		    if ($prisig ne $asig) {
			pp_warn("(bases) primary '$p' and alt '$a' have different signs");
		    }
		    $altsigs{$asig} = $a;
		    $altsigs{"$asig#code"} = $pcode;
		    $altsigs{$a} = $asig;
		}
	    }
	}
    }

    # 3. Does a primary occur as an alternate?
    foreach my $p (sort keys %vbases) {
	next if $p =~ /\#/;
	my $prisig = $prisigs{$p};
	if ($prisig && $altsigs{$prisig}) {
	    my $vbpc = $vbases{"$p#code"};
	    my $aspc = $altsigs{"$prisig#code"};
	    pp_warn("(bases) primary '$p' is also an alt of '$altsigs{$prisig}'")
		unless  $vbpc == $aspc;
	}
    }

    # 4. For compounds, if it isn't in the sign list does it use the right component names?
    #
    # We do this one by collecting all the bases that contain elements with compounds and
    # then using an external script to do the heavy lifting
    foreach my $p (sort keys %vbases) {
	next if $p =~ /\#/;
	if ($p =~ /\|/) {
	    if ($p =~ tr/|/|/ % 2) {
		pp_warn("(bases) odd number of pipes in compound");
	    } else {
		cpd_add($p);
	    }
	    # warn "#4: $p\n";
	    # while ($p =~ s/^.*?(\|[^|]+\|)//) {
	    # 	my $c = $1;
	    # 	warn "c10e: $c\n";
	    # 	my $shouldbe = ORACC::SL::BaseC::c10e_compound($c);
	    # 	pp_sl_messages();
	    # }
	}
    }

    if ($trace && exists $arg_vfields{'bases'}) {
	pp_trace "v_bases: dump of \%ORACC::CBD::bases:";
	pp_trace Dumper \%ORACC::CBD::bases;
    }
}

sub pp_sl_messages {
    my $p = shift || '';
    my @m = ORACC::SL::BaseC::messages();
    if ($#m >= 0) {
	foreach my $m (@m) {
	    if ($p =~ /^\|(.*?)\|$/) {
		my $novb = $1;
		next if $m =~ $novb;
	    }
	    pp_warn("(bases) ".$m);
	}
	1
    } else {
	0
    }
}

sub v_form {
    my($tag,$arg) = @_;

    $arg = '' unless $arg;
    
    if ($trace) {
	pp_trace "v_form: tag=$tag; arg='$arg'; lang=$lang";
    }
    
    unless ($arg) {
	pp_warn("empty \@form");
	return;
    }

    if ($arg =~ /^[\%\$\#\@\+\/\*]/) {
	pp_warn("\@form must begin with writing of form (arg=$arg)");
	return;
    }

    if ($ORACC::CBD::Forms::external) {
	&ORACC::CBD::Forms::forms_register_inline(pp_file(), pp_line(), $curr_cfgw, $arg);
	return;
    }
    
    my $barecheck = $arg;
    $barecheck =~ s/^(\S+)\s*//;
    my $formform = $1;
    my $tmpform = $formform; $tmpform =~ tr/_/ /;
    atf_add($tmpform) if $tmpform;

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
    } elsif ($lang =~ /^qpn/) {
	pp_warn("no %LANG in QPN glossary \@form entry");
    }

    my($fo) = ($f =~ /^(\S+)/);
    if ($ORACC::CBD::forms{$curr_cfgw,$fo,$flang}++) {
	pp_warn("duplicate form in `$curr_cfgw': $fo");
	return;
    }

    if ($fo =~ tr/_/ / && !$is_compound) {
	pp_warn("underscore (_) not allowed in form except in compounds");
    }
    
    if (($lang =~ /^akk/ 
	 || ($lang =~ /^qpn/ && $flang =~ /akk/))) {
	pp_warn("no normalization in form")
	    unless $f =~ m#(?:^|\s)\$\S#;
    }

    if (($lang =~ /^sux/ 
	 || ($lang =~ /^qpn/ && $flang =~ /^sux/))
	&& !$is_compound) {
	$f =~ m#(?:^|\s)/(\S+)#;
	my $b = $1;
	if ($b) {
	    unless ($bases{$b}) {
		unless (${$ORACC::CBD::bases{$curr_cfgw}}{$b}) {
		    my $warned = 0;
		    my $a = ${$ORACC::CBD::bases{$curr_cfgw}}{"#$b"};
		    if ($a) {
			pp_warn("alt BASE $b should be primary $a");
			$warned = 1;
		    }
		    pp_warn("BASE $b not known for `$curr_cfgw'")
			unless $warned;
		}
	    }
	} else {
	    pp_warn("no BASE entry in form")
	}
    }

    if ($f =~ /\s\+(\S+)/) {
	my $c = $1;
	pp_warn("malformed CONT '$c'")
	    unless $c =~ /^-(.*?)=(.*?)$/;
    }

    my $morph = '';
    if ($f =~ /\s\#([^\#]\S*)/) {
	$morph = $1;
    } elsif (($lang =~ /^sux/ 
	      || ($lang =~ /^qpn/ && $flang =~ /^sux/))
	     && !$is_compound
	) {
	pp_warn("no MORPH in form");
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
	    pp_trace "v_form COF: ndoll=$ndoll; nparen=$nparen";
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

    ++$seen_sense;
    
    if ($arg =~ s/^\[(.*?)\]\s+//) {
#	$sgw = $1;
    }

    my($pre,$etag,$pst) = ($tag =~ /^($acd_rx)?\@(\S+?)(\!?)$/);

    if ($pre) {
	if ($global_cbd[pp_line()-1] =~ /^$acd_rx/) {
	    pp_warn("multiple acd \@sense fields in a row not permitted");
	} else {
	    push @{$data{'edit'}}, pp_line()-1;
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

sub v_stems {
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
    pp_warn("no SENSE in \@entry") unless $seen_sense;
    foreach my $b (keys %bases) {
	if ($b =~ /^#/) {
	    ${$ORACC::CBD::bases{$curr_cfgw}}{$b} = $bases{$b};
	} else {
	    ++${$ORACC::CBD::bases{$curr_cfgw}}{$b}
	    unless ${$ORACC::CBD::bases{$curr_cfgw}}{$b};
	}
    }
    $curr_cfgw = '';
    $in_entry = $seen_bases = 0;
    %bases = ();
}

sub v_deprecated {
    pp_warn("$_[0] is deprecated, please remove from glossary");
}

sub is_proper {
    $_[0] && $_[0] =~ /^[A-Z]N$/;
}

sub v_proplist {
    my($tag,$arg) = @_;
    push @{$data{'proplist'}}, pp_line()-1;
    proplist($arg);
}

sub v_prop {
    my($tag,$arg) = @_;
    prop($arg);
}

sub v_alias {
    my($tag,$arg) = @_;
}

sub v_pl_id {
    my($tag,$arg) = @_;
}

sub v_pl_uid {
    my($tag,$arg) = @_;
}

sub v_pl_coord {
    my($tag,$arg) = @_;
}

sub v_is_entry {
    $seen_entries{$_[0]};
}

sub v_set_cfgw {
    $curr_cfgw = $_[0];
    my($cf) = ($curr_cfgw =~ /^(.*?)\s*\[/);
    $is_compound = ($cf =~ /\s/);
}

1;
