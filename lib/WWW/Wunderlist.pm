package WWW::Wunderlist;

use 5.008008; # for JSON::XS
use strict;
use warnings;

use Class::Accessor::Lite (
    new => 0,
    rw  => [qw(email password warnings endpoint_url)],
);

use Carp qw(carp croak);
use LWP::UserAgent;
use JSON;
use WWW::Wunderlist::Task;
use WWW::Wunderlist::List;

use constant ENDPOINT_URL => 'https://api.wunderlist.com';
use constant DEBUG => $ENV{DEBUG};

our $VERSION = "0.01";
our $UA_NAME = "Perl/WWW::Wunderlist/$VERSION";

# my $wl = WWW::Wunderlist->new( email => YOUR_EMAIL, password => YOUR_PASSWORD );
sub new {
    my $class = shift;
    my %arg   = @_;
    my $self  = {};
    $self->{email}    = delete $arg{email};
    $self->{password} = delete $arg{password};
    $self->{warnings} = delete $arg{warnings};
    $self->{endpoint_url} = ENDPOINT_URL; # for deligation.
    if ( $self->{warnings} && $self->{warnings} ne 'FATAL' ) {
        # In this version, warnings key is allowed "FATAL" only.
        delete $self->{warnings};
    }
    return bless $self, $class;
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

# error report. it call carp or croak
# TODO: logging?
sub error {
    my $self = shift;
    my $message = shift;
    my $is_fatal = $self->{warnings} && $self->{warnings} eq 'FATAL';
    if ( $is_fatal ) {
        croak $message;
    }
    else {
        carp $message;
    }
}

# $wl->login()
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
    $self->{latest_http_response} = $res;
    return $res->is_success;
}

sub settings {
    my $self = shift;
    local $@;
    if ( eval { $self->{login_data} && $self->{login_data}->{settings} } ) {
        return $self->{login_data}->{settings};
    }
    else {
        return +{ error => $@ };
    }
}

sub latest_http_response {
    my $self = shift;
    $self->{latest_http_response} = shift if @_;
    return $self->{latest_http_response};
}

*previous_http_response = \&latest_http_response;

sub logout {
    my $self = shift;
    $self->ua->default->header( Authorization => undef );
    delete $self->{login_time};
    return;
}

###
### tasks
###

# my @tasks = $wl->get_tasks();
# return WWW::Wunderlist::Task objects.
sub get_tasks {
    my $self = shift;
    my $res = $self->ua->get( ENDPOINT_URL . '/me/tasks' );
    $self->latest_http_response($res);
    if ( $res->is_success ) {
        my $collection = $self->json->utf8->decode($res->content);
        my @tasks;
        for my $task_data (@$collection) {
            my $task = WWW::Wunderlist::Task->new($task_data, $self);
            push @tasks, $task;
        }
        return wantarray ? @tasks : \@tasks;
    }
    else {
        if ( DEBUG ) {
            warn $res->as_string;
        }
        $self->error("get_task is failed.");
        return;
    }
}

# my $task = $wl->post_task(
#     list_id => LIST_ID,
#     title => TITLE_UTF8_STRING,
#     starred => BOOL, ### optional
#     due_date => ISO_FORMAT_DATE, ### optional
# );
# post task data to server by Wunderlist API.
# return WWW::Wunderlist::Task object if request is success.
# but request is not success, return undef.
sub post_task {
    my $self = shift;
    my %args = @_;
    my $list_id  = $args{list_id} || "inbox";
    my $list_name = $args{list_name};
    my $title    = $args{title};
    my $starred  = $args{starred}; # optional (0 or 1)
    my $due_date = $args{due_date}; # optional (The date is in ISO format. Example: 2012-12-30T06:00:28Z)

    if ( $list_id && $list_name ) {
        $self->error("can not specify togeter list_id and list_name.");
    }

    # search $list_id
    if ( $list_name ) {
        my @lists = $self->get_lists();
        for my $list (@lists) {
            my $this_list_name = $list->{title};
            if ( $list_name eq $this_list_name ) {
                $list_id = $list->{id};
                last;
            }
        }
        if ( !$list_id ) {
            $self->error("failed guess list_name from list_id.");
        }
    }

    if ( !$list_id ) {
        $self->error("can not find list_id.");
    }

    my $res = $self->ua->post(
        ENDPOINT_URL . '/me/tasks',
        { list_id => $list_id,
          title   => $title,
          ( defined $starred ? $starred : () ),
          ( defined $due_date ? $due_date : () ), }
    );
    $self->latest_http_response($res);
    if ( $res->is_success ) {
        my $task = WWW::Wunderlist::Task->new(
            $self->json->utf8->decode($res->content),
            $self,
        );
        return $task;
    }
    else {
        if ( DEBUG ) {
            warn $res->as_string;
        }
        $self->error("post_task is failed.");
        return;
    }
}

###
### lists
###

# my @lists = $wl->get_lists();
# return WWW::Wunderlist::List objects.
sub get_lists {
    my $self = shift;
    my $res = $self->ua->get( ENDPOINT_URL . '/me/lists' );
    $self->previous_http_response($res);
    if ( $res->is_success ) {
        #return $self->json->utf8->decode($res->content);
        my $collection = $self->json->utf8->decode($res->content);
        my @lists;
        for my $list_data (@$collection) {
            my $list = WWW::Wunderlist::List->new($list_data, $self);
            push @lists, $list;
        }
        return wantarray ? @lists : \@lists;
    }
    else {
        if ( DEBUG ) {
            warn $res->as_string;
        }
        $self->error("get_lists is failed.");
        return;
    }
}

# my $list = $wl->post_list( title => TITLE_UTF8_STRING );
# return WWW::Wunderlist::List object.
sub post_list {
    my $self = shift;
    my %args = @_;
    my $title    = delete $args{title};
    my $res = $self->ua->post(
        ENDPOINT_URL . '/me/lists',
        { title   => $title }
    );
    $self->latest_http_response($res);
    if ( $res->is_success ) {
        my $list = WWW::Wunderlist::List->new(
            $self->json->utf8->decode($res->content),
            $self,
        );
        return $list;
    }
    else {
        if ( DEBUG ) {
            warn $res->as_string;
        }
        $self->error("post_lists is failed.");
        return;
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
        # warnings => "FATAL", # If you want to exception when method is failed.
    );
    $wl->login()
        or die "login failed.";
    my @tasks = $wl->get_tasks()
        or die "get_tasks failed.";
    # title key's value is UTF-8 decoded string.
    $wl->post_task( title => 'Test of add task at' . localtime . ' #hashtag')
        or die "set_tasks failed.";

    my @lists = $wl->get_lists()
        or die "get_lists failed.";
    $wl->post_list( title => 'New List' )
        or die "post_list failed.";

=head1 DESCRIPTION

WWW::Wunderlist is L<Wunderlist|https://wunderlist.com>'s API wrapper.

Wunderlist offers us to some task operation APIs.
This module is those wrapper.

Wunderlist API does not offer OAuth authentication.
Insted, legacy username/password authentication.
You use this module, give those information to new constructor.

=head1 METHODS

=head2 my $wl = WWW::Wunderlist->new( ... )

 my $wl = WWW::Wunderlist->new(
     email => 'your@example.jp',
     password => 'xxx'
 );

 my $wl = WWW::Wunderlist->new(
     email => 'your@example.jp',
     password => 'xxx',
     warnings => "FATAL",
 );

It creates Wunderlist API object.
Give your registered "email" and "password" to argument as key-value pair.

If warnings key is specifiend and this value is "FATAL",
then this object methods throw exception with method failing.
This mode is called "FATAL mode" on this document.

By default, when object method is failed,
this method reports warning (Carp::carp).

=head2 $wl->login()

Tring login. It object accesses Wunderlist API server for login.

If login is success, it returns true.
But login is failed, it returns false.

When "FATAL mode", login is failed, it thorws exception;

 my $wl = WWW::Wunderlist->new(
     email => 'your@example.jp',
     password => 'xxx',
     warnings => 'FATAL'
 );
 local $@;
 eval { $wl->login() };
 if ( $@ ) {
     ...
     # your_log_method( "exception occured: " . $@ );
     exit 1;
 }

=head2 my $settings = $wl->settings()

It returns settings data which is HASH reference.

You can call this method after "login".
Before login, It returns undef.

See L<Wunderlist API|https://wunderpy.readthedocs.org/en/latest/wunderlist_api/index.html> for detail.

=head2 my $res = $wl->latest_http_response()

It returns latest HTTP response as HTTP::Response object.
You can use it for DEBUG and some scene.

=head2 $wl->logout()

Do logout.

Expire some tokens of having the instance object.

=head2 my @tasks = $wl->get_tasks()

It returns all tasks.

Return value is list of L<WWW::Wunderlist::Task> objects on list context,
or ARRAY reference which has L<WWW::Wunderlist::Task> objects on scalar context.

See L<WWW::Wunderlist::Task> for detail.

For calling it, $wl->login()ed already.

=head2 my $task = $wl->post_task( ... )

 my $task = $wl->post_task(
     list_id  => LIST_ID,
     title    => TITLE_UTF8_STRING,
     starred  => BOOL, ### optional
     due_date => ISO_FORMAT_DATE, ### optional
 );

It posts task data by WWW::Wunderlist API.

If it's post is success, then it returns WWW::Wunderlist::Task object.
But it's post is failed, then it returns undef.

See L<WWW::Wunderlist::Task> for detail.

For calling it, $wl $wl->login()ed already.

=head2 my @lists = $wl->get_lists()

It returns all lists.
Return value is list of WWW::Wunderlist::List objects on list context,
or ARRAY reference which has WWW::Wunderlist::List objects on scalar context.

See L<WWW::Wunderlist::List> for detail.

For calling it, $wl $wl->login()ed already.

=head2 my $list = $wl->post_list( ... )

 my $task = $wl->post_list(
     title => TITLE_UTF8_STRING,
 );

This method posts list data by WWW::Wunderlist API.

If it's post is success, then it returns WWW::Wunderlist::List object.
But it's post is failed, then it returns undef.

See L<WWW::Wunderlist::List> for detail.

For calling it, $wl $wl->login()ed already.

=head1 CAUTION

B<THIS VERSION IS ALPHA RELEASE.>

B<THIS MODULE IS NOT SUPPORT ALL WUNDERLIST APIs.>

B<UNDER DEVELOPMENT YET.>

=head1 SEE ALSO

L<Wunderlist API|https://wunderpy.readthedocs.org/en/latest/wunderlist_api/index.html>

=head1 LICENSE

Copyright (C) OGATA Tetsuji.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

OGATA Tetsuji E<lt>tetsuji.ogata {at} gmail.comE<gt>

=cut

