use strict;
use Test::More;

use lib 'lib';

use_ok $_ for qw(
    WWW::Wunderlist
    WWW::Wunderlist::Task
    WWW::Wunderlist::List
);

done_testing;

