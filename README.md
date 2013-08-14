# NAME

WWW::Wunderlist - Wunderlist API wrapper

# SYNOPSIS

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

# DESCRIPTION

WWW::Wunderlist is [Wunderlist](https://wunderlist.com)'s API wrapper.

Wunderlist offers us to some task operation APIs.
This module is those wrapper.

Wunderlist API does not offer OAuth authentication.
Insted, legacy username/password authentication.
You use this module, give those information to new constructor.

# CAUTION

THIS VERSION IS ALPHA RELEASE.
THIS MODULE IS NOT SUPPORT ALL WUNDERLIST APIs.
UNDER DEVELOPMENT YET.

# LICENSE

Copyright (C) OGATA Tetsuji.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

OGATA Tetsuji \<tetsuji.ogata {at} gmail.com\>
