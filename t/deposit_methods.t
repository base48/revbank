use v5.36;
use Test2::V0;
use File::Temp ();
use File::Basename qw(basename);

use RevBank::Plugins;
use RevBank::Shell;
use FindBin; BEGIN { $FindBin::RealBin = "."; }  # XXX yuck

my $tmpdir = File::Temp->newdir;
$ENV{REVBANK_DATADIR} = $tmpdir->dirname;
RevBank::FileIO::populate_datadir;

$ENV{REVBANK_PLUGINS} = "adduser deposit users";
$ENV{REVBANK_PLUGINDIR} = "./plugins";

my $called = 0;
my $desc;
package TestMethods {
	use RevBank::Global;
	use parent 'RevBank::Plugin';
	sub id { 'testmethods' }

	sub hook_deposit_methods($class, $message, $hash, @) {
		$called = 1;
		$$message = '';
		%$hash = (
			none => {
				description => "No prompts",
			},
			one => {
				description => "One prompt (answer: %s)",
				prompts => [ "First" ],
			},
			two => {
				description => "Two prompts (answers: %s, %s)",
				prompts => [ "First", "Second"],
			},
			cash => {
				description => "Sets contra to -cash implicitly"
			},
			none_contra => {
				description => "No prompts",
				contra => "-specialcontra1",
			},
			one_contra => {
				description => "One prompt (answer: %s)",
				prompts => [ "First" ],
				contra => "-specialcontra2",
			},
		);
	}

	sub hook_added_entry ($class, $cart, $entry, @) {
		$desc = $entry->{description};
	}
}

RevBank::Plugins::load;
open STDOUT, ">", "/dev/null";

BEGIN {
	*balance = \&RevBank::Accounts::balance;
	*ex = \&RevBank::Shell::exec;
}

ex "adduser aap";
my $b = 0;

ex "deposit 1; aap";
is balance("aap")->cents, $b += 100, "Simple deposit (no methods) works";

RevBank::Plugins::register 'TestMethods';

ex "deposit 1; aap";
is balance("aap")->cents, $b, "Deposit without method no longer works";

ex "deposit 1 none; aap";
ok $called, "hook_deposit_methods was called";
is balance("aap")->cents, $b += 100;
is balance("-deposits/none")->cents, -100;
is $desc, "No prompts";

ex "deposit 1 one 'first answer'; aap";
is balance("aap")->cents, $b += 100;
is balance("-deposits/one")->cents, -100;
is $desc, "One prompt (answer: first answer)";

ex "deposit 1 two 'first answer' 'second answer'; aap";
is balance("aap")->cents, $b += 100;
is balance("-deposits/two")->cents, -100;
is $desc, "Two prompts (answers: first answer, second answer)";

ex "deposit 1 cash; aap";
is balance("aap")->cents, $b += 100;
is balance("-cash")->cents, -100;
is $desc, "Sets contra to -cash implicitly";

ex "deposit 1 none_contra; aap";
is balance("aap")->cents, $b += 100;
is balance("-specialcontra1")->cents, -100;
is $desc, "No prompts";

ex "deposit 1 one_contra 'first answer again'; aap";
is balance("aap")->cents, $b += 100;
is balance("-specialcontra2")->cents, -100;
is $desc, "One prompt (answer: first answer again)";

done_testing;
