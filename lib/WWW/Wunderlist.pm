package WWW::Wunderlist;

use 5.008008; # for JSON::XS
use strict;
use warnings;

use LWP::UserAgent;
use JSON;

use constant ENDPOINT_URL => 'https://api.wunderlist.com';
use constant DEBUG => $ENV{DEBUG};

our $VERSION = "0.01";
our $UA_NAME = "Perl/WWW::Wunderlist/$VERSION";

sub new {
    my $class = shift;
    my %arg   = @_;
    my $self  = {};
    $self->{email}    = delete $arg{email};
    $self->{password} = delete $arg{password};
    return bless $self, $class;
}

sub email {
    my $self = shift;
    $self->{email} = shift if @_;
    return $self->{email};
}

sub password {
    my $self = shift;
    $self->{password} = shift if @_;
    return $self->{password};
}

# accessor of LWP::UserAgent instance
sub ua {
    my $self = shift;
    return $self->{ua} if $self->{ua};
    my $ua = LWP::UserAgent->new( agent => $UA_NAME );
    $ua->env_proxy;
    return $self->{ua} = $ua;
}

# accessor of JSON instance
sub json {
    my $self = shift;
    return $self->{json} if $self->{json};
    return $self->{json} = JSON->new->allow_nonref;
}

sub login {
    my $self = shift;
    my $res = $self->ua->post(
        ENDPOINT_URL . '/login',
        { email => $self->email, password => $self->password }
    );
    if ( $res->is_success ) {
        $self->{login_data} = $self->json->utf8->decode($res->content);
        $self->{login_time} = time();
        my $token = $self->{login_data}->{token};
        warn "token is $token\n" if DEBUG;
        $self->ua->default_header( Authorization => "Bearer $token" );
    }
    else {
        warn $res->as_string;
    }
    $self->{previous_http_response} = $res;
    return $res->is_success;
}

sub login_with_token {
    my $self = shift;
    ...
}

sub previous_http_response {
    my $self = shift;
    $self->{previous_http_response} = shift if @_;
    return $self->{previous_http_response};
}

sub logout {
    my $self = shift;
    $self->ua->default->header( Authorization => undef );
    delete $self->{login_time};
    return;
}

### me
sub me {
    my $self = shift;
    ...
}

### tasks

sub get_tasks {
    my $self = shift;
    my $res = $self->ua->get( ENDPOINT_URL . '/me/tasks' );
    $self->previous_http_response($res);
    if ( $res->is_success ) {
        # BETA: とりあえずJSON構造をPerlの構造にして返却
        return $self->json->utf8->decode($res->content);
    }
    else {
        if ( DEBUG ) {
            warn "get_tasks: FAILED\n";
            warn $res->as_string;
        }
        return;
    }
}

sub set_tasks {
    my $self = shift;
    my %args = @_;
    my $list_id  = delete $args{list_id} || "inbox";
    my $title    = delete $args{title};
    my $starred  = delete $args{starred}; # optional (0 or 1)
    my $due_date = delete $args{due_date}; # optional (The date is in ISO format. Example: 2012-12-30T06:00:28Z)
    my $res = $self->ua->post(
        ENDPOINT_URL . '/me/tasks',
        { list_id => $list_id,
          title   => $title,
          ( defined $starred ? $starred : () ),
          ( defined $due_date ? $due_date : () ), }
    );
    $self->previous_http_response($res);
    if ( $res->is_success ) {
        # BETA: とりあえずJSON構造をPerlの構造にして返却
        return $self->json->utf8->decode($res->content);
    }
    else {
        if ( DEBUG ) {
            warn "set_tasks: FAILED\n";
            warn $res->as_string;
        }
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

WWW::Wunderlist - Wunderlist API wrapper

=head1 SYNOPSIS

    use WWW::Wunderlist;
    my $wl = WWW::Wunderlist->new(
        email    => YOUR_EMAIL,
        password => YOUR_PASSWORD,
    );
    $wl->login()
        or die "login failed.";
    my $tasks = $wl->get_tasks()
        or die "get_tasks failed.";
    # title key's value is UTF-8 decoded string.
    $wl->set_tasks( title => 'Test of add task at' . time() )
        or die "set_tasks failed.";

=head1 DESCRIPTION

WWW::Wunderlist is L<Wunderlist|https://wunderlist.com>'s API wrapper.

Wunderlist offers us to some task operation APIs.
This module is those wrapper.

Wunderlist API does not offer OAuth authentication.
Insted, legacy username/password authentication.
You use this module, give those information to new constructor.

=head1 CAUTION

THIS VERSION IS ALPHA RELEASE.
THIS MODULE IS NOT SUPPORT ALL WUNDERLIST APIs.
UNDER DEVELOPMENT YET.

=head1 LICENSE

Copyright (C) OGATA Tetsuji.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

OGATA Tetsuji E<lt>tetsuji.ogata {at} gmail.comE<gt>

=cut

