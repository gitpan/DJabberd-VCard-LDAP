package DJabberd::Plugin::VCard::LDAP;

use warnings;
use strict;

use base 'DJabberd::Plugin::VCard';

use Net::LDAP;

our $logger = DJabberd::Log->get_logger();

=head1 NAME

DJabberd::VCard::LDAP - LDAP VCard Provider for DJabberd

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Provides an LDAP VCard backend for DJabberd

    <Vhost mydomain.com>
	<Plugin DJabberd::Plugin::VCard::LDAP>
            LDAPURI		ldap://localhost/
            LDAPBindDN		cn=reader
            LDAPBindPW		pass
            LDAPBaseDN		ou=people
            LDAPFilter		(uid=%u)
	</Plugin>
    </VHost>

LDAPURI , LDAPBaseDN, and LDAPFilter are required
Everything else is optional.

LDAPFilter is an LDAP filter with a %u that will be substituted with the incoming userid (w/o the domain)

=cut

sub set_config_ldapuri {
    my ($self, $ldapuri) = @_;
    if ( $ldapuri =~ /((?:ldap[si]?\:\/\/)?[\w\.%\d]+\/?)/ ) {
        $self->{'ldap_uri'} = $ldapuri;
    }
}

sub set_config_ldapbinddn {
    my ($self, $ldapbinddn) = @_;
    $self->{'ldap_binddn'} = $ldapbinddn;
}

sub set_config_ldapbindpw {
    my ($self, $ldapbindpw) = @_;
    $self->{'ldap_bindpw'} = $ldapbindpw;
}

sub set_config_ldapbasedn {
    my ($self, $ldapbasedn) = @_;
    $self->{'ldap_basedn'} = $ldapbasedn;
}

sub set_config_ldapfilter {
    my ($self, $ldapfilter) = @_;
    $self->{'ldap_filter'} = $ldapfilter;
}

sub finalize {
    my $self = shift;
    $logger->error_die("Invalid LDAP URI") unless $self->{ldap_uri};
    $logger->error_die("No LDAP BaseDN Specified") unless $self->{ldap_basedn};
    $logger->error_die("Must specify filter with userid as %u") unless $self->{ldap_filter};

    # Initialize ldap connection
    $self->{'ldap_conn'} = Net::LDAP->new($self->{ldap_uri})
	or $logger->error_die("Could not connect to LDAP Server ".$self->{ldap_uri});

    if (defined $self->{'ldap_binddn'}) {
        if (not $self->{'ldap_conn'}->bind($self->{'ldap_binddn'},
    		password=>$self->{'ldap_bindpw'})) {
    	    $logger->error_die("Could not bind to ldap server");
    	}
    }

    $self->SUPER::finalize;
}

sub _isdef {
    my $arg = shift;
    return $arg if defined $arg;
    return '';
}

sub load_vcard {
    my ($self, $user) = @_;

    my $suser = $user;
    $suser =~ s/^(.*)\@.*$/$1/;

    my $filter = $self->{'ldap_filter'};
    $filter =~ s/%u/$suser/;
    $logger->info("Searching $filter on ".$self->{'ldap_basedn'});
    my $srch = $self->{'ldap_conn'}->search(
	base=>$self->{'ldap_basedn'},
	filter=>$filter,
	attrs=>['dn','sn','cn','givenName','mail','telephoneNumber','title','description','displayName']);
    if ($srch->code || $srch->count < 1) {
	$logger->info("Account $user not found.");
	return;
    } else {
        my $entry = $srch->entry(0);
	my $vCard = '<vCard xmlns="vcard-temp" version="3.0">'
		.'<FN>'._isdef($entry->get_value('cn')).'</FN>'
		.'<N>'
		    .'<FAMILY>'._isdef($entry->get_value('sn')).'</FAMILY>'
		    .'<GIVEN>'._isdef($entry->get_value('givenName')).'</GIVEN>'
		.'</N>'
		.'<TITLE>'._isdef($entry->get_value('title')).'</TITLE>'
		.'<NICKNAME>'._isdef($entry->get_value('displayName')).'</NICKNAME>'
		.'<TEL><HOME/><VOICE/><NUMBER>'._isdef($entry->get_value('telephoneNumber')).'</NUMBER></TEL>'
		.'<EMAIL><INTERNET/><PREF/><USERID>'._isdef($entry->get_value('mail')).'</USERID></EMAIL>'
		.'<JABBERID>'.$user.'</JABBERID>'
		.'<DESC>'._isdef($entry->get_value('description')).'</DESC>'
	    .'</vCard>';
        undef($entry);
        undef($srch);
	return $vCard;
    }
}


sub store_vcard { 0 }

=head1 AUTHOR

Edward Rudd, C<< <urkle at outoforder.cc> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DJabberd::Plugin::VCard::LDAP

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 Edward Rudd, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of DJabberd::Plugin::VCard::LDAP
