# -*- perl -*-

requires 'perl', '5.008008';

# Common
requires 'Carp';
requires 'Class::Accessor::Lite';
requires 'JSON';
requires 'LWP::UserAgent';

recommends 'JSON::XS';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

#on configure => sub { }
#on develop => sub { }
