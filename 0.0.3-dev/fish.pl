# -=FISH Version 0.0.3 Beta=-
# (F)ile
# (I)ntegrity tool by
# (S)arid
# (H)arper (sharpe)
# (!)FISH three times a week!
$|=1;

use fish;

# Create an instance of the fish class
my $objfish = fish->NEW("config.xml");

$objfish->begin();

# Destroy the object
$objfish = undef;
