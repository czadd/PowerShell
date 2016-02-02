<#
.Synopsis
   Create a deck of cards and shuffle it.
.DESCRIPTION
   This is an experiment to see if I can create a deck of cards and shuffle it. Later I will probably try to make it deal out a simple card game like blackjack.
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>

Function New-CardSuit{
    $CardsPerSuit = @()
    $CardsPerSuit += [PsCustomObject]@{Name='A';Value=1;AltValue=11}
    $CardsPerSuit += [PsCustomObject]@{Name='K';Value=10;AltValue=10}
    $CardsPerSuit += [PsCustomObject]@{Name='Q';Value=10;AltValue=10}
    $CardsPerSuit += [PsCustomObject]@{Name='J';Value=10;AltValue=10}
    2..10 | Foreach{ $CardsPerSuit += [PsCustomObject]@{Name=$_.tostring();Value=$_;AltValue=$_} }
    $CardsPerSuit | sort value, name
}

Function Remove-card { 
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][Object]$CardSet,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=1)][String]$CurrentCard
    )
    $CardSet = $CardSet | Where { $_ -notmatch $CurrentCard }
    $CardSet
}

Function Get-TopCard( $CardSet ){
    $CardSet | select -First 1
}

Function Start-Shuffle ($CardSet) {
    $TotalCardCount = $Cardset.count
    $NewCardSet = @()
    $i=0
    Do{
        $i++
        $CurrentCard = $CardSet | Get-Random
        $NewCardSet += $CurrentCard
        $CardSet = $CardSet | Where { $_ -notmatch $CurrentCard }
    }
    Until( $i -ge $TotalCardCount)
    $NewCardSet
}

$Suit = 'Spades','Hearts','Clubs','Diamonds'

$Deck = Foreach( $S in $Suit ){
    Foreach( $Card in New-CardSuit ){
        $Card | Select-Object -Property *,@{label='Suit';Expression={$S}}
    }
}

$Deck = Start-Shuffle $Deck

$TotalCardCount = $Deck.count

$ShuffledDeck = For( $i = 0; $i -lt $TotalCardCount; $i++ ){
    $TopCard = Get-TopCard $Deck
    $Deck = Remove-card $Deck $Topcard
    [PscustomObject] @{Name = $TopCard.Name;Suit=$TopCard.Suit}
}
$ShuffledDeck | ft -AutoSize