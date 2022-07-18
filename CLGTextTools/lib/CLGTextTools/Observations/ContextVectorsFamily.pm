package CLGTextTools::Observations::ContextVectorsFamily;

use strict;
use warnings;
use File::Slurp;
use CLGTextTools::Observations::ObsFamily;
use Data::Dumper qw(Dumper);
use CLGTextTools::Logging qw/confessLog cluckLog/;
use Scalar::Util qw(looks_like_number);

our $gramSeparator = " ";

our @ISA=qw/CLGTextTools::Observations::ObsFamily/;

sub new {
    my ($class, $params) = @_;
    my $self = $class->SUPER::new($params, __PACKAGE__);

    return $self;
}

# CONTEXT.<pattern>.lc[01].sw[01].n[0-9]
# for now all options are disabled

# TODO: need to use $self variables in internal functions.
sub addObsType {
    my $self = shift;
    # obsType in the form of WORD.
    my $obsType = shift;

    if (defined($self->{observs}->{$obsType})) {
        cluckLog($self->{logger}, "Ignoring observation type '$obsType', already initialized.");
    } else {
        $self->{observs}->{$obsType} = {};
        my ($patternStr, $lc, $sw, $n, $vocabId) = ($obsType =~ m/^CONTEXT\.([TS]+)\.lc([01])\.sw([01])\.n([0-9])(?:\.(.+))?$/);
        confessLog($self->{logger}, "Invalid obs type '$obsType'") if (!length($patternStr) || !length($lc) || !length($n) || !length($sw));
        $self->{logger}->debug("Adding obs type '$obsType': pattern='$patternStr', lc='$lc', sw='$sw', n='$n'") if ($self->{logger});
        $self->{params}->{$obsType}->{lc} = (defined($lc) && ($lc eq "1"));
        $self->{params}->{$obsType}->{sw} = (defined($sw) && ($sw eq "1"));
        $self->{params}->{$obsType}->{n} = $n if (defined($n) && ($n ne "0"));
        
        $self->{lc} = $self->{lc} || $self->{params}->{$obsType}->{lc};
        $self->{sw} = $self->{sw} || $self->{params}->{$obsType}->{sw};
        $self->{n} = $self->{n} || $self->{params}->{$obsType}->{n};

        # $self->{params}->{$obsType}->{lc} = 1;
        # $self->{params}->{$obsType}->{sl} = 0;

        # set pattern for calculating ngrams
        my @pattern;
        for (my $i = 0; $i < $self->{n}; $i++) {
            push(@pattern, 1);
        }

        $self->{params}->{$obsType}->{pattern} = \@pattern;
        $self->{nbDistinctNGrams}->{$obsType} = 0;
        $self->{nbTotalNGrams}->{$obsType} = 0;
        $self->{obsType} = $obsType;
    }
}

# TODO: call generate context vectors and return a hash with token: cvector as its structure.
sub getObservations {
    my $self = shift;

    # print Dumper \$self->{contextVectors};

    return $self->{contextVectors};    
}

# generate and save context vectors in object
sub addText {
    my $self = shift;
    my $text = shift;

    my %contextVectorHash = $self->_generateContextVectors(\$text);

    my @tokens = split(/\s+/, $text);
    my $nbTokens = scalar(@tokens);
    my $obsType = $self->{obsType};

    my @lcTokens;
    my $lc = 1;
    @lcTokens = map {lc} (@tokens) if ($self->{lc});
    my @tokensCase = (\@tokens, \@lcTokens); # tokensCase[1] not initialized if lc not needed
    my $selectedTokens = $tokensCase[$lc];

    # # TODO: define selectedTokens
    my $p = $self->{params}->{$obsType}->{pattern};
    for (my $i=0; $i<$nbTokens; $i++) {
        if ($i + scalar(@$p) <= $nbTokens) {
            my @ngram;
            for (my $j=0; $j<scalar(@$p); $j++) {
                push(@ngram, $selectedTokens->[$i+$j]) if ($p->[$j]);
            }
            $self->_addNGram(\@ngram, $obsType);
        }
    }
    
    $self->{contextVectors} = \%contextVectorHash;
}

sub _addNGram {
    my $self = shift;
    my $ngramArray = shift;
    my $obsType = shift;

    my $ngramStr = join($gramSeparator, @$ngramArray);
    
    confessLog($self->{logger}, "Bug: empty ngram!") if (length($ngramStr)==0);
    $self->{logger}->trace("Adding ngram '$ngramStr' for obsType '$obsType'") if ($self->{logger});
    $self->{nbDistinctNGrams}->{$obsType}++ if (!defined($self->{observs}->{$obsType}->{$ngramStr}));
    $self->{observs}->{$obsType}->{$ngramStr}++;
    $self->{nbTotalNGrams}->{$obsType}++;
}

sub _generateContextVectors {
    my $self = shift;
    my $text = shift;

    my $fileContents = ${$text};

    #TODO: filepath
    # my $filePath = $self->{filename}; #shift; #$_[0];

    my $n = $self->{n};
    my $removeStopWords = $self->{sw};

    # my @text = getDataFromFile(\$filePath, \$removeStopWords);
    my @text = getTextArrayFromString($fileContents);
    # print(@text);

    my %indexes = createIndexOfTokens(\@text, \$n);
    my $numberOfTokens = keys %indexes;

    my @subRoutineHashes = getHashOfFrequencyRanking(\@text);
    my %hashTokenRanking = %{$subRoutineHashes[0]};
    my %hashRankingToken = %{$subRoutineHashes[1]};

    # TODO: return in createAfterArray.
    my %contextVectorHash = createAfterArray(\@text, \$n, \$numberOfTokens, \%indexes, \%hashTokenRanking, \%hashRankingToken);
    
    return %contextVectorHash;
}


# INTERNAL FUNCTIONS

# TODO: check data processing here
sub getTextArrayFromString {
    my $textContent = shift;
    $textContent =~ s/([^\w\s]+)/ $1 /g;
    $textContent =~ s/^\s+//; # remove possible whitespaces at the start and end of the text
    $textContent =~ s/\s+$//;

    $textContent =~ s/[^\S]{2,}//g; 
    # print($textContent);

    my @text;
    my @sentences = split(/\./, $textContent);
    foreach my $sentence (@sentences) {
        # print"$sentence\n";
        my @wordsInSentence = split(' ', $sentence);
        my $line = join(' ', @wordsInSentence);
        $line = lc($line);
        # print($line, "\n");
        push(@text, $line);
        push(@text, " ");
    }
    return @text;
}

# previous version of function.
# get text from file.
# sub getDataFromFile($) {
#     # open and read file into a string variable.
#     my $fileName = $_[0]; 
#     my $removeStopWords = $_[1];
#     my $fileContents = read_file($fileName);

#     my @text;
#     my @sentences = split(/\./, $fileContents);
#     foreach my $sentence (@sentences) {
#         # print"$sentence\n";
#         my @wordsInSentence = split(' ', $sentence);
#         my $line = join(' ', @wordsInSentence);
#         # print($line, "\n");
#         push(@text, $line);
#     }
#     return @text;
# }

sub getHashOfFrequencyRanking {
    my @text = @{$_[0]};
    my %hashFrequency;
    
    foreach my $line (@text) {
        my @words = split(' ', $line);
        foreach my $word (@words) {
            $word =~ s/[[:punct:]]//g;;
            $hashFrequency{$word}++;
        }
    }

    my @sortedHash = sort { $hashFrequency{$b} <=> $hashFrequency{$a} } keys %hashFrequency;

    my %hashTokenRanking;
    my %hashRankingToken;

    my $i = 1;
    foreach my $key (@sortedHash) {
        $hashTokenRanking{$key} = $i;
        $hashRankingToken{$i} = $key;
        $i++;
    }

    # print Dumper \%hashTokenRanking;

    return (\%hashTokenRanking, \%hashRankingToken);
}

# get a hash with key as token and value as index for reference later in the array.
sub createIndexOfTokens {
    my @text = @{$_[0]};
    my %indexes = ();
    my $index = 0;

    for my $row (@text) {
        my @wordsInSentence = split(' ', $row);
        foreach my $word (@wordsInSentence) {
            $word =~ s/[[:punct:]]//g;
            $word = lc($word);
            if (!exists($indexes{$word})) {
                $indexes{$word} = $index;
                $index++;
            }
        }
    }

    # print Dumper \%indexes;

    return %indexes;
}

# creates a hash with word frequency and also returns other outputs. 
sub createWordDictionary {
    my @text = @{$_[0]};

    my %wordToIndex;
    my %indexToWord;
    my @corpus;
    my $indexCount = 0;
    my $vocabularySize = 0;

    for my $row (@text) {
        # print("$row");
        my @wordsInSentence = split(' ', $row);
        foreach my $word (@wordsInSentence) {
            $word = lc($word);
            push(@corpus, $word);
            # check if word is not indexed.
            if (!exists($wordToIndex{$word})) {
                $wordToIndex{$word} = $indexCount;
                $indexToWord{$indexCount} = $word;
                $indexCount++;
            }
        }
    }

    $vocabularySize = keys %wordToIndex;
    my $length = @corpus;
    return \(%wordToIndex, %indexToWord, @corpus, $vocabularySize, $length);
}


# i => length of indexed hash or the counter used in it for values
# j => n
# array length => number of tokens 

sub createAfterArray {
    my @sentences = @{$_[0]};
    my $n = ${$_[1]};
    my $numberOfTokens = ${$_[2]};
    
    my %hashWordRank = %{$_[3]};
    my %hashTokenRanking = %{$_[4]};
    my %hashRankingToken = %{$_[5]};

    # print Dumper \%hashWordRank;
    # print Dumper \%hashTokenRanking;

    my $text = join('', @sentences);
    # regex to filter out punctuation characters and numerals.
    $text =~ s/[^a-zA-Z ]+//g;
    my @wordsInText = split(' ', $text);
    my $nbWords = @wordsInText;

    my @after = ();
    my @before = ();

    # i is the word index iterator
    for my $i (0 .. $#wordsInText) {
        my $word = $wordsInText[$i];
        $word = lc($word);
        # print($word);

        my $targetWordIndex = $hashWordRank{$word};

        # position of context word (1 to n) for nGram.
        for my $position (1 .. $n) {
            # check if position + word index is within last index of text array.
            if ($i + $position < $#wordsInText or defined($wordsInText[$i + $position])) {
                my $contextWord = $wordsInText[$i + $position];
                my $contextWordIndex = $hashTokenRanking{$contextWord};
                # print("word ", $contextWord);
                # print("index ", $contextWordIndex);

                if ( !defined($after[$targetWordIndex][$position]) ) {
                    # create a new array to replace the undef value.
                    my @relFreqAtPositionJ = (0) x $numberOfTokens;
                    $relFreqAtPositionJ[$contextWordIndex - 1]++;
                    $after[$targetWordIndex][$position] = \@relFreqAtPositionJ;
                } else {
                    my $relFreqAtPositionJRef = $after[$targetWordIndex][$position];
                    # TODO check this
                    @{$relFreqAtPositionJRef}[$contextWordIndex - 1]++;
                    $after[$targetWordIndex][$position] = \@{$relFreqAtPositionJRef};
                }
            }


            # for before
            if ($i - $position >= 0 or defined($wordsInText[$i - $position])) {
                my $contextWord = $wordsInText[$i - $position];
                my $contextWordIndex = $hashWordRank{$contextWord};

                if ( !defined($before[$targetWordIndex][$position]) ) {
                    # create a new array to replace the undef value.
                    my @relFreqAtPositionJ = (0) x $numberOfTokens;
                    $relFreqAtPositionJ[$contextWordIndex - 1]++;
                    $before[$targetWordIndex][$position] = \@relFreqAtPositionJ;
                } else {
                    my $relFreqAtPositionJRef = $before[$targetWordIndex][$position];
                    # TODO check this
                    @{$relFreqAtPositionJRef}[$contextWordIndex - 1]++;
                    $before[$targetWordIndex][$position] = \@{$relFreqAtPositionJRef};
                }
            }
        }
    }

    # print Dumper \@after;
    # print Dumper \@before;

    my %contextVectorHash;

    for (my $token = 0; $token < $numberOfTokens; $token++) {
        my @cv = ();
        my $index = 0;
        my $tokenValue = $hashRankingToken{$token + 1}; # index starting from 1

        for (my $j = $n; $j >= 1; $j--) { # for each position is an array.
            if (defined(\@{$before[$token][$j]})) {
                $cv[$token][$index] = $before[$token][$j];
            } else {
                my @emptyArray = (0) x $numberOfTokens;
                $cv[$token][$index] = @emptyArray;
            }
            $index++;
        }

        for (my $j = 1; $j <= $n; $j++) {
            if (defined(\@{$after[$token][$j]})) {
                # print Dumper \@{$after[$token][$j]};
                $cv[$token][$index] = $after[$token][$j];
            } else {
                my @emptyArray = (0) x $numberOfTokens;
                $cv[$token][$index] = @emptyArray;
            }
            $index++;
        }
    
        # print("token ", $tokenValue);
        # print Dumper \$cv[$token];


        # flatten array and add undefined positions to be zero.
        my @cvForToken = ();
        my $indexForFinalCVArray = 0;

        for(my $i = 0; $i < $n * 2; $i++) {
            for(my $j = 0; $j < $numberOfTokens; $j++) {
                if (defined $cv[$token][$i][$j]) {
                    $cvForToken[$indexForFinalCVArray] = $cv[$token][$i][$j];
                } else {
                    $cvForToken[$indexForFinalCVArray] = 0;
                }
                $indexForFinalCVArray++;
            }
        }

        # @cv = normalizeVector(\@cvForToken, \$numberOfTokens);
        # print Dumper \@cvForToken;

        $contextVectorHash{$tokenValue} = \@cvForToken; # was token
        @cv = ();
    }

    # HARDCODE: number of tokens in hash
    # NOTICE: if changing the key, change it everywhere else in exclusions.
    $contextVectorHash{"nbWords"} = \$nbWords;
    $contextVectorHash{"hashTokenRanking"} = \%hashTokenRanking;
    $contextVectorHash{"hashRankingToken"} = \%hashRankingToken;

    return %contextVectorHash;
}

sub normalizeVector {
    my @cv = @{$_[0]};
    my $nbTokens = $_[1];

    foreach my $val (@cv) {
        $val = $val / ${$nbTokens};
        # print(looks_like_number($val));
    }

    # print(${$nbTokens});
    # print Dumper \@cv;
    
    return @cv;
}

