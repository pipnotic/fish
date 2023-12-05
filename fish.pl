# -=FISH Version 0.2=-
# Contact: Sarid Harper, saridski@yahoo.dk
# Written: 01.2006

# Please send any questions or comments to the address above
# Feel free to do what ever you wish with this programme and its code

# Install XML-XPath before using this programme, if running it with the 
# Perl interpreter
$|=1;

use fish;

# Create an instance of the fish class
my $objfish = fish->NEW("config.xml");

$objfish->begin();

# Destroy the object
$objfish = undef;
