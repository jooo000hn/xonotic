#!/usr/bin/perl

package WeaponEncounterProfile;
use strict;
use warnings;

sub new
{
	my ($cls, $filename) = @_;
	my $self = bless { fn => $filename }, 'WeaponEncounterProfile';
	$self->load();
	return $self;
}

sub load($)
{
	my ($self) = @_;
	$self->{stats} = {};
	$self->{mapstats} = {};
	$self->{addrstats} = {};
	$self->{allstats} = {};
	open my $fh, "<", $self->{fn}
		or return;
	while(<$fh>)
	{
		chomp;
		/^$/ and next;
		/^#/ and next;
		/^\/\// and next;
		my ($addr, $map, $attackerweapon, $targweapon, $value);
		if(/^([^\t]+)\t(\S+)\t(\d+) (\d+)\t(\d+) (\d+)\t(\d+) (\d+) (\S+)$/)
		{
			# new format (Xonotic)
			($addr, $map, $attackerweapon, $targweapon) = ($1, $2, $3, $5);
			next if $4 and not $ENV{WEAPONPROFILER_WITHBOTS};
			next if $6 and not $ENV{WEAPONPROFILER_WITHBOTS};
			$value =
				$ENV{WEAPONPROFILER_DAMAGE} ? $9 :
				$ENV{WEAPONPROFILER_HITS} ? $8 :
				$7;
		}
		elsif(/^([^\t]+)\t(\S+)\t(\d+)\t(\d+)\t(\S+)$/)
		{
			# legacy format (Nexuiz)
			($addr, $map, $attackerweapon, $targweapon, $value) = ($1, $2, $3, $4, $5);
		}
		else
		{
			print STDERR "UNRECOGNIZED: $_\n";
			next;
		}
		$targweapon = int $self->weaponid_from_name($targweapon)
			if $targweapon ne int $targweapon;
		$attackerweapon = int $self->weaponid_from_name($attackerweapon)
			if $attackerweapon ne int $attackerweapon;
		$self->{stats}->{$addr}{$map}{$attackerweapon}{$targweapon} += $value;
		$self->{mapstats}->{$map}{$attackerweapon}{$targweapon} += $value;
		$self->{addrstats}->{$addr}{$attackerweapon}{$targweapon} += $value;
		$self->{allstats}->{$attackerweapon}{$targweapon} += $value;
	}
}

sub save($)
{
	my ($self) = @_;
	open my $fh, ">", $self->{fn}
		or die "save: $!";
	while(my ($addr, $addrhash) = each %{$self->{stats}})
	{
		while(my ($map, $maphash) = each %$addrhash)
		{
			while(my ($attackerweapon, $attackerweaponhash) = each %$maphash)
			{
				while(my ($targweapon, $value) = each %$attackerweaponhash)
				{
					print $fh "$addr\t$map\t$attackerweapon\t$targweapon\t$value\n";
				}
			}
		}
	}
}

sub event($$$$$$)
{
	my ($self, $addr, $map, $attackerweapon, $targweapon, $type) = @_;
	return if $map eq '';
	if($type > 0)
	{
		$self->{stats}->{$addr}{$map}{$attackerweapon}{$targweapon} += $type;
		$self->{mapstats}->{$map}{$attackerweapon}{$targweapon} += $type;
		$self->{addrstats}->{$addr}{$attackerweapon}{$targweapon} += $type;
		$self->{allstats}->{$attackerweapon}{$targweapon} += $type;
	}
}

sub allstats($$)
{
	my ($self, $callback) = @_;
	# send global stats
	$callback->(undef, undef, $self->{allstats});
	# send per-host stats
	while(my ($k, $v) = each %{$self->{addrstats}})
	{
		$callback->($k, undef, $v);
	}
	# send per-map stats
	while(my ($k, $v) = each %{$self->{mapstats}})
	{
		$callback->(undef, $k, $v);
	}
	# send single stats
	while(my ($k1, $v1) = each %{$self->{stats}})
	{
		while(my ($k2, $v2) = each %$v1)
		{
			$callback->($k1, $k2, $v2);
		}
	}
}

our %WeaponMap = (
         1 => ["Laser", "laser"],
         2 => ["Shotgun", "shotgun"],
         3 => ["Uzi", "uzi"],
         4 => ["Mortar", "gl"],
         5 => ["Mine Layer", "minelayer"],
         6 => ["Electro", "electro"],
         7 => ["Crylink", "crylink"],
         8 => ["Nex", "nex"],
         9 => ["Hagar", "hagar"],
        10 => ["Rocket Launcher", "rl"],
        11 => ["Port-O-Launch", "porto"],
        12 => ["MinstaNex", "minstanex"],
        13 => ["Grappling Hook", "hookgun"],
        14 => ["Heavy Laser Assault Cannon", "hlac"],
        15 => ["@!#%'n Tuba", "tuba"],
        16 => ["Sniper Rifle", "sniperrifle"],
        17 => ["Fireball", "fireball"],
        18 => ["Seeker", "seeker"],
);

sub weaponid_valid($$)
{
	my ($self, $id) = @_;
	return exists $WeaponMap{$id};
}

sub weaponid_to_name($$)
{
	my ($self, $id) = @_;
	exists $WeaponMap{$id} or warn "weapon of id $id not found\n";
	return $WeaponMap{$id}[0];
}

sub weaponid_to_model($$)
{
	my ($self, $id) = @_;
	exists $WeaponMap{$id} or warn "weapon of id $id not found\n";
	return $WeaponMap{$id}[1];
}

sub weaponid_from_name($$)
{
	my ($self, $name) = @_;
	for(keys %WeaponMap)
	{
		return $_
			if $WeaponMap{$_}[0] eq $name;
	}
}

1;
