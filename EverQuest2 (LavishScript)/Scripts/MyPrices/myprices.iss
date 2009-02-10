;
; MyPrices  - EQ2 Broker Buy/Sell script
;
; Version 0.13g :  released 10rd February 2009
;
; Declare Variables
;
variable BrokerBot MyPrices
variable bool MatchLowPrice
variable bool IncreasePrice
variable bool TakeCoin=FALSE
variable bool Exitmyprices=FALSE
variable bool Pausemyprices=TRUE
variable bool MerchantMatch
variable bool SetUnlistedPrices
variable bool ItemUnlisted
variable bool ScanSellNonStop
variable bool BuyItems
variable bool MinPriceSet
variable bool IgnoreCopper
variable bool SellItems
variable bool Craft
variable bool Logging
variable bool Natural
variable bool MatchActual
variable bool MaxPriceSet
variable bool runautoscan
variable bool runplace
variable bool ItemNotStack
; Array stores bool - Item scanned
variable bool Scanned[1000]
; Array stores bool - to scan box or not
variable bool box[6]

variable string labelname
variable string currentitem
variable string MyPriceS
variable string MinBasePriceS
variable string SellLoc
variable string SellCon
variable string CurrentChar

variable int i
variable int j
variable int Commission
variable int IntMinBasePrice
; Array - stores container number for each item in the Listbox
variable int itemprice[1000]
variable int numitems
variable int currentpos
variable int currentcount
variable int BuyNumber
variable int PauseTimer
variable int WaitTimer
variable int StopWaiting
variable int InventorySlotsFree=${Me.InventorySlotsFree}
variable int ClickID

variable float MyBasePrice
variable float MerchPrice
variable float PriceInSilver
variable float MinSalePrice
variable float MaxSalePrice
variable float MinPrice=0
variable float MinBasePrice=0
variable float ItemPrice=0
variable float MyPrice=0
variable float BuyPrice

variable settingsetref CraftList
variable settingsetref CraftItemList
variable settingsetref BuyList
variable settingsetref BuyName
variable settingsetref BuyItem
variable settingsetref ItemList
variable settingsetref Item
variable settingsetref General

variable filepath CraftPath="${LavishScript.HomeDirectory}/Scripts/EQ2Craft/Character Config/"
variable filepath XMLPath="${LavishScript.HomeDirectory}/Scripts/MyPrices/XML/"
variable filepath BackupPath="${LavishScript.HomeDirectory}/Scripts/MyPrices/Backup/"
variable filepath MyPricesUIPath="${LavishScript.HomeDirectory}/Scripts/MyPrices/UI/"
variable filepath LogPath="${LavishScript.HomeDirectory}/Scripts/MyPrices/"


; Main Script
;
function main(string goscan, string goscan2)
{
#define WAITEXTPERIOD 120
	call AddLog "Verifying ISXEQ2 is loaded and ready" FF11CCFF
	wait WAITEXTPERIOD ${ISXEQ2.IsReady}
	if !${ISXEQ2.IsReady}
	{
		echo ISXEQ2 could not be loaded. Script aborting.
		Script:End
	}

	variable int loopcount=0

	ISXEQ2:ResetInternalVendingSystem
	CurrentChar:Set[${Me.Name}]
	MyPrices:loadsettings
	; backup the current settings file on script load
	LavishSettings[myprices]:Export[${BackupPath}${Me.Name}_MyPrices.XML]

	MyPrices:LoadUI
	MyPrices:InitTriggersAndEvents
	
	Event[EQ2_onInventoryUpdate]:AttachAtom[EQ2_onInventoryUpdate]
	Event[EQ2_onChoiceWindowAppeared]:AttachAtom[EQ2_onChoiceWindowAppeared]
	
	call AddLog "Running MyPrices 0.13g :  released 10rd February 2009" FF11FFCC
	call echolog "0.13g :  released 10rd February 2009"
	
	call StartUp	

	if ${goscan.Equal["PLACE"]} || ${goscan2.Equal["PLACE"]}
	{
		Pausemyprices:Set[FALSE]
		runplace:Set[TRUE]
		UIElement[Start Scanning@Sell@GUITabs@MyPrices]:SetText[Stop and Quit]
	}

	if ${goscan.Equal["SCAN"]} || ${goscan2.Equal["SCAN"]}
	{
		Pausemyprices:Set[FALSE]
		runautoscan:Set[TRUE]
		UIElement[Start Scanning@Sell@GUITabs@MyPrices]:SetText[Stop and Quit]
	}

	do
	{
		; wait for the GUI Start Scanning button to be pressed
		
		do
		{
			if !${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[Errortext].Text.Equal["** Waiting **"]}
				UIElement[Errortext@Sell@GUITabs@MyPrices]:SetText["** Waiting **"]

			if !${Me.Name.Equal[${CurrentChar}]}
			{
				
				Echo Character changed , exiting script
				Script:End
			}
			ExecuteQueued
			Waitframe
			; exit if the Stop and Quit Button is Pressed
			if ${Exitmyprices}
			{
				Script:End
			}
		}
		While ${Pausemyprices}

		UIElement[Errortext@Sell@GUITabs@MyPrices]:SetText[" **Processing**"]
		call echolog "Start Scanning"
		call echolog "**************"
		call LoadList

		PauseTimer:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[PauseTimer].Text}]
		call SaveSetting PauseTimer ${PauseTimer}
		
		; if paramater PLACE used then run place crafted items routine
		if ${runplace} 
		{
			call buy item place
			; if the scan paramater hasn't been set then don't do anything else
			if !${runautoscan}
			{
				exitmyprices:Set[TRUE]
				break
			}
		}
		
		; Start scanning the broker
		if ${SellItems}
		{
			; reset all the main script counters to 1
			currentpos:Set[1]
			currentcount:Set[1]
			call resetscanned
			i:Set[1]
			j:Set[1]

			do
			{
				Call CheckFocus
				currentitem:Set["${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[ItemList].Item[${currentpos}]}"]
				
				; container number
				i:Set[${itemprice[${currentpos}]}]


				; check where the container is being sold from to get the commission %

				SellLoc:Set[${Me.Vending[${i}].Market}]
				SellCon:Set[${Me.Vending[${i}]}]

				if ${Me.Vending[${i}].CurrentCoin} > 0 && ${TakeCoin}
				{
					Me.Vending[${i}]:TakeCoin
				}

				if ${SellLoc.Equal["Haven"]}
				{
					Commission:Set[40]
				}
				else
				{
					Commission:Set[20]
				}
				if ${SellCon.Equal["Veteran's Display Case"]} || ${SellCon.Equal["Veteranen-Vitrine"]}
				{
					Commission:Set[${Math.Calc[${Commission}/2]}]
				}

				; Find where the Item is stored in the container
				call FindItem ${i} "${currentitem}"

				j:Set[${Return}]

				; If item was found in the container still
				if ${j} != -1
				{
					; is the item listed for sale ?
					if ${Me.Vending[${i}].Consignment[${j}].IsListed}
					{
						ItemUnlisted:Set[FALSE]
					}
					else
					{
						ItemUnlisted:Set[TRUE]
					}
					if !${ItemUnlisted} || ${SetUnlistedPrices}
					{
						; Calclulate the price someone would pay with commission
						MyBasePrice:Set[${Me.Vending[${i}].Consignment[${j}].BasePrice}]
						MerchPrice:Set[${Me.Vending[${i}].Consignment[${j}].Value}]
						MyPrice:Set[${Math.Calc[((${MyBasePrice}/100)*${Math.Calc[100+${Commission}]})]}]
						; If increase price is flag set
						if ${IncreasePrice}
						{
							; Unlist the item to make sure it's not included in the check for higher prices
							loopcount:Set[0]
							do
							{
								Call CheckFocus
								Me.Vending[${i}].Consignment[${j}]:Unlist
								wait 10
								; check the item hasn't moved in the list because it was unlisted
								call FindItem ${i} "${currentitem}"
								j:Set[${Return}]
							}
							while ${Me.Vending[${i}].Consignment[${j}].IsListed} && ${loopcount:Inc} < 10
						}
						call SetColour ${currentpos} FF0B0301
						; check to see if the items minimum price should be used or not
						Call CheckMinPriceSet "${currentitem}"
						MinPriceSet:Set[${Return}]
						Call CheckMaxPriceSet "${currentitem}"
						MaxPriceSet:Set[${Return}]

						broker Name "${currentitem}" Sort ByPriceAsc MaxLevel 999

						; scan to make sure the item is listed and get lowest price , TRUE means exact name match only
						Call echolog "<Main> Call BrokerSearch ${currentitem} TRUE"
						Call BrokerSearch "${currentitem}" TRUE

						; Broker search returns -1 if no items to compare were found
						if ${Return} != -1
						{
							; record the minimum broker price
							MinPrice:Set[${Return}]

							; check if the item has a MaxPrice
							call checkmaxitem "${currentitem}"
							MaxSalePrice:Set[${Return}]

							; check if the item is in the myprices settings file
							call checkitem "${currentitem}"
							MinSalePrice:Set[${Return}]

							; if a stored Sale price was found then carry on
							if ${MinSalePrice}!= -1
							{
								;if my current price is less than my minimum price then increase it
								if (${MyBasePrice} < ${MinSalePrice}) && !${ItemUnlisted} && ${MinPriceSet}
								{
									MinBasePrice:Set[${MinSalePrice}]
									call StringFromPrice ${MinSalePrice}
									call AddLog "${currentitem} : Item price lower than your Minimum Price : ${Return}" FFFF0000
								}
								else
								{
									if ${MatchActual}
									{
										MinBasePrice:Set[${MinPrice}]
									}
									else
									{
										MinBasePrice:Set[${Math.Calc[((${MinPrice}/${Math.Calc[100+${Commission}]})*100)]}]
									}
									; if the flag to ignore copper is set and the price is > 1 gold
									if ${IgnoreCopper} && ${MinBasePrice} > 100
									{
										; round the value to remove the coppers
										IntMinBasePrice:Set[${MinBasePrice}]
										MinBasePrice:Set[${IntMinBasePrice}]
									}
								}

								; do conversion from silver value to pp gp sp cp format
								call StringFromPrice ${MyPrice}
								MyPriceS:Set[${Return}]

								; ***** If your price is less than what a merchant would buy for ****
								if ${MerchantMatch} && ${MyPrice} < ${MerchPrice} && !${ItemUnlisted}
								{
									Call echolog "<Main> (Match Mechant Price)"
									call SetItemPrice ${i} ${j} ${MerchPrice}
									MinBasePrice:Set[${MerchPrice}]
									call StringFromPrice ${MerchPrice}
									call AddLog "${currentitem} : Merchant Would buy for : ${Return}" FFFF0000
								}

								; ***** If your price is more than the lowest price on sale ****
								if ${MinPrice}<${MyPrice}
								{
									if ${MerchantMatch} && ${MinBasePrice} < ${MerchPrice}
									{
										MinBasePrice:Set[${MerchPrice}]
										call StringFromPrice ${MerchPrice}
										call AddLog "${currentitem} : Merchant Would buy for  more : ${Return}" FFFF0000
										call SetColour ${currentpos} FFFF0000
									}
									; **** if that price is Less than the price you are willing to sell for , don't do anything
									if ${MinBasePrice}<${MinSalePrice} && ${MinPriceSet}
									{
										call StringFromPrice ${MinBasePrice}
										MinBasePriceS:Set[${Return}]
										call StringFromPrice ${MinSalePrice}
										call AddLog "${currentitem} : ${MinBasePriceS} : My Lowest : ${Return}" FFFF0000
										; Set the text in the list box line to red
										call SetColour ${currentpos} FFFF0000
									}
									else
									{
										; If you have a maximum price set and the sale price is > than that
										; then use the maximum price you will allow.
										if ${MinBasePrice}>${MaxSalePrice} && ${MaxPriceSet}
										{
											MinBasePrice:Set[${MaxSalePrice}]
											call StringFromPrice ${MaxSalePrice}
											call AddLog "${currentitem} : Price higher than you will allow: ${Return}" FFFF0000
										}
										
										; otherwise inform/change value to match
										call StringFromPrice ${MinBasePrice}
										call AddLog "${currentitem} :  Price to match is ${Return}" FF00FF00
										If ${MatchLowPrice}
										{
											call SetColour ${currentpos} FF00FF00
											Call echolog "<Main> (Match Price change)"
											call SetItemPrice ${i} ${j} ${MinBasePrice}
											Me.Vending[${i}].Consignment[${j}]:SetPrice[${MinBasePrice}]
										}
									}
								}
								; **** if you are selling an item lower than the next lowest price
								elseif ${MyPrice}<${MinPrice}
								{
									; Set the colour of the listbox line to green initially
									call SetColour ${currentpos} FF00FF00
									; if you have told the script to match higher prices or the item was unlisted
									if ${IncreasePrice} || ${ItemUnlisted}
									{
										If !${ItemUnlisted}
										{
											; If you have a maximum price set and the sale price is > than that
											; then use the maximum price you will allow.
											if ${MinBasePrice}>${MaxSalePrice} && ${MaxPriceSet}
											{
												MinBasePrice:Set[${MaxSalePrice}]
											}
											call StringFromPrice ${MinBasePrice}
											call AddLog "${currentitem} : Price to match is ${Return} :" FF00FF00
											Call echolog "<Main> (Increase Price)"
											call SetItemPrice ${i} ${j} ${MinBasePrice}
										}
										else
										; if the item was unlisted then update your sale price
										{
											; if a minimum price was set previously for this item then use that value
											if ${MinBasePrice}<${MinSalePrice} && ${MinPriceSet}
											{
												call StringFromPrice ${MinSalePrice}
												call AddLog "${currentitem} : Unlisted : Setting to ${Return}" FFFF0000
												Call echolog "<Main> (Unlisted Item - Min Sale price)"
												call SetItemPrice ${i} ${j} ${MinSalePrice}
												Call Saveitem Sell "${currentitem}" ${MinSalePrice} ${MinSalePrice}
												call SetColour ${currentpos} FFFF0000
											}
											else
											{
												; otherwise use the lowest price on the vendor or your highest price allowed
												if ${MinBasePrice}>${MaxSalePrice} && ${MaxPriceSet}
												{
													MinBasePrice:Set[${MaxSalePrice}]
												}
												call StringFromPrice ${MinBasePrice}
												call AddLog "${currentitem} : Unlisted : Setting to ${Return}" FF00FF00
												Call echolog "<Main> (Unlisted Item - Lowest Broker Price)"
												call SetItemPrice ${i} ${j} ${MinBasePrice}
												; if no previous minimum price was saved then save the lowest current price (makes sure a value is there)
												if ${MinSalePrice} == 0
												{
													Call Saveitem Sell "${currentitem}" ${MinBasePrice} ${MinBasePrice}
												}
												call SetColour ${currentpos} FF0000FF
											}
										}
									}
								}
								Else
								{
									call SetColour ${currentpos} FF00FF00
								}
							}
							else
							{
								call AddLog "Adding ${currentitem} at ${MyBasePrice}" FF00CCFF
								call Saveitem Sell "${currentitem}" ${MyBasePrice} ${MyBasePrice}
							}

							; Re-List item for sale
								call ReListItem ${i} "${currentitem}"

						}
						else
						{
							; if the item has a maximum price saved then use this
							if ${MaxPriceSet}
							{
								; Find where the Item is stored in the container
								call FindItem ${i} "${currentitem}"
								j:Set[${Return}]
								; Read the maximum price you will allow and set it to that price								
								call checkmaxitem "${currentitem}"
								call SetItemPrice ${i} ${j} ${Return}
							}
							else
							{
								; if if no match or max price was found and the item was STILL listed for sale before
								; then re-list it
								if !${ItemUnlisted}
								{
									call ReListItem ${i} "${currentitem}"
								}
							}
						}
						; if the Quit Button on the UI has been pressed then exit
						if ${Exitmyprices}
						{
							call AddLog "Exit Pressed , closing script."
							Script:End
						}
					}
				}
				else
				{
					; Item not found in the container (sold or removed mid-scan)
					call SetColour ${currentpos} FFC43012
				}
				; Mark position in list as scanned
				Scanned[${currentpos}]:Set[TRUE]
				; Choose the next item in the list to be looked at
				if ${Natural} && ${currentcount} < ${numitems}
				{
					call ChooseNextItem ${numitems}
					currentpos:Set[${Return}]
					wait ${Math.Rand[60]}
				}
				else
				{
					currentpos:Inc
				}
			}
			while ${currentcount:Inc} <= ${numitems} && ${Pausemyprices} == FALSE

			UIElement[Errortext@Sell@GUITabs@MyPrices]:SetText[" ** Finished **"]

		}
		; Script starts to scan for items to buy if flagged.
		if ${BuyItems} && ${Pausemyprices} == FALSE
		{
			call buy Buy scan
		}

		if !${ScanSellNonStop}
		{
			UIElement[Start Scanning@Sell@GUITabs@MyPrices]:SetText[Start Scanning]
			Pausemyprices:Set[TRUE]
		}
		
		if ${runautoscan} || ${runplace}
		{
			Exitmyprices:Set[TRUE]
			ScanSellNonStop:Set[FALSE]
		}

		if ${ScanSellNonStop} && ${PauseTimer} > 0
		{
			if ${Natural}
			{
				WaitTimer:Set[${Math.Calc[600*${PauseTimer}]}]
				; get 1% of the pause time
				WaitTimer:Set[${Math.Calc[${WaitTimer}/100]}]
				; multiply it with between -20 and +20 to get a +/- 20% varience
				WaitTimer:Set[${Math.Calc[(${Math.Rand[40]}-20)*${WaitTimer}]}]
				; Reduce / Increase time by the random %
				WaitTimer:Set[${Math.Calc[(${PauseTimer}*600)+${WaitTimer}]}]
				call AddLog "Pausing for ${Math.Calc[${WaitTimer}/600]} minutes " FF0033EE
			}
			else
			{
				call AddLog "Pausing for ${PauseTimer} minutes " FF0033EE
				WaitTimer:Set[${Math.Calc[600*${PauseTimer}]}]
			}
			wait ${WaitTimer} ${StopWaiting}
			StopWaiting:Set[0]
		}
	}
	While ${Exitmyprices} == FALSE
}

function addtotals(string itemname, int itemnumber)
{
	call echolog "->  addtotals ${itemname} ${itemnumber}"
	LavishSettings:AddSet[craft]
	LavishSettings[craft]:AddSet[CraftItem]

	Declare Totals int local

	CraftList:Set[${LavishSettings[craft].FindSet[CraftItem]}]


	if ${CraftList.FindSetting[${itemname}](exists)}
	{
		Totals:Set[${CraftList.FindSetting[${itemname}]}]
		CraftList:AddSetting[${itemname},${Math.Calc[${Totals}+${itemnumber}]}]
	}
	else
	{
		CraftList:AddSetting[${itemname},${itemnumber}]
	}
	call echolog "<end> : addtotals"
}

function FindItem(int i, string itemname)
{
	call echolog "-> FindItem ${i} ${itemname}"
	Call CheckFocus
	Declare j int local
	Declare Position int -1 local
	Declare ConName string local

	j:Set[1]
	do
	{
		ConName:Set["${Me.Vending[${i}].Consignment[${j}]}"]
		if ${ConName.Equal["${itemname}"]}
		{
			Position:Set[${j}]
			Break
		}
	}
	while ${j:Inc} <= ${Me.Vending[${i}].NumItems}
	call echolog "<- FindItem ${Position}"
	Return ${Position}
}


function ReListItem(int i, string itemname)
{
	call echolog "-> ReListItem ${i} ${itemname}"
	Call CheckFocus
	Declare loopcount int local
	Declare j int local

	Call FindItem ${i} "${itemname}"
	j:Set[${Return}]
	if ${j} != -1
	{
		if !${Me.Vending[${i}].Consignment[${j}].IsListed}
		{
			call echolog "${itemname} (${i}, ${j}) is not listed for sale : ${Me.Vending[${i}].Consignment[${j}].IsListed}"
			call echolog "Me.Vending[${i}].Consignment[${j}].BasePrice Returned ${Me.Vending[${i}].Consignment[${j}].BasePrice}"

			if ${Me.Vending[${i}].Consignment[${j}].BasePrice} >0
			{
				; Re-List the item for sale
				loopcount:Set[0]
				do
				{
					Me.Vending[${i}].Consignment[${j}]:List
					wait 15
					Call FindItem ${i} "${itemname}"
					j:Set[${Return}]
				}
				while !${Me.Vending[${i}].Consignment[${j}].IsListed} && ${loopcount:Inc} < 10
				if ${loopcount} == 10
				{
					call AddLog "*** ERROR - unable to mark ${itemname} as listed for sale" FFFF0000
				}
			}
			else
			{
				call AddLog "*** ERROR - Item was marked as ZERO value - unlisting from sale" FFFF0000
				loopcount:Set[0]
				do
				{
					Me.Vending[${i}].Consignment[${j}]:Unlist
					wait 15
					; check the item hasn't moved in the list because it was unlisted
					call FindItem ${i} "${currentitem}"
					j:Set[${Return}]
				}
				while ${Me.Vending[${i}].Consignment[${j}].IsListed} && ${loopcount:Inc} < 10
				if ${loopcount} == 10
				{
					call AddLog "*** ERROR - unable to mark ${itemname} as Unlisted" FFFF0000
				}
			}
		}
	}
	else
	{
		; item was moved or sold
		call SetColour ${currentpos} FFC43012
	}
	call echolog "<end> : ReListItem"
}

function checkstock()
{
	call echolog "<start> : checkstock"

	LavishSettings[newcraft]:Clear

	LavishSettings[newcraft]:Import[${CraftPath}${Me.Name}.xml]

	CraftItemList:Set[${LavishSettings[newcraft].FindSet[Recipe Favourites]}]

	CraftItemList:AddSet[_myprices]

	CraftList:Set[${CraftItemList.FindSet[myprices]}]

	CraftItemList[myprices]:Clear

	CraftList:Set[${CraftItemList.FindSet[_myprices]}]

	CraftItemList[_myprices]:Clear

	call buy Craft scan

	UIElement[Errortext@Sell@GUITabs@MyPrices]:SetText[" ** Finished **"]

	call echolog "<end> : checkstock"
}

function buy(string tabname, string action)
{
	
	call echolog "-> buy Tab : ${tabname} Action : ${action}"
	; Read data from the Item Set
	;
	Declare CraftItem bool local
	Declare CraftStack int local
	Declare CraftMinTotal int local
	Declare CraftRecipe string local
	Declare Harvest bool local
	Declare Recipe string local

	Declare AutoTransmute bool local
	Declare BuyAttuneOnly bool local
	Declare BuyNameOnly bool local
	Declare startlevel int local
	Declare endlevel int local
	Declare tier int local
	Declare box int local
	
	if ${tabname.Equal["Buy"]}
	{
		BuyList:Set[${LavishSettings[myprices].FindSet[Buy]}]
	}
	else
	{
		BuyList:Set[${LavishSettings[myprices].FindSet[Item]}]
	}

	if ${action.Equal["init"]}
	{
		UIElement[ItemList@${tabname}@GUITabs@MyPrices]:ClearItems
	}

	variable iterator BuyIterator
	variable iterator NameIterator
	variable iterator BuyNameIterator

	; Index each item under the Set [Item]

	BuyList:GetSetIterator[BuyIterator]

	; if there is anything in the index

	if ${BuyIterator:First(exists)}
	{

		;start going through each Sub-Set under [Item]
		do
		{
			; Get the Sub-Set Location
			NameIterator.Value:GetSetIterator[BuyIterator]
			do
			{
				; Get the reference for the Sub-Set
				BuyName:Set[${BuyList.FindSet[${BuyIterator.Key}]}]
				; Create an Index of all the data in that Sub-set
				BuyName:GetSettingIterator[BuyNameIterator]
				; run the various options (Scan / update price etc based on the parameter passed to the routine
				;
				; init = build up the list of items on the buy tab
				; scan = check the broker list one by one - do buy and various workhorse routines

				if ${action.Equal["init"]} && ${tabname.Equal["Buy"]}
				{
					UIElement[ItemList@Buy@GUITabs@MyPrices]:AddItem["${BuyIterator.Key}"]
				}
				else
				{
					; read the Settings in the Sub-Set
					if ${BuyNameIterator:First(exists)}
					{
						; Scan the subset to get all the settings
						CraftItem:Set[FALSE]
						Harvest:Set[FALSE]
						CraftRecipe:Set[NULL]
						AutoTransmute:Set[FALSE]
						BuyAttuneOnly:Set[FALSE]
						BuyNameOnly:Set[FALSE]
						do
						{
							Switch "${BuyNameIterator.Key}"
							{
								Case BuyNumber
									BuyNumber:Set[${BuyNameIterator.Value}]
									break
								Case BuyPrice
									BuyPrice:Set[${BuyNameIterator.Value}]
									break
								Case Harvest
									Harvest:Set[${BuyNameIterator.Value}]
									break
								Case BuyAttuneOnly
									BuyAttuneOnly:Set[${BuyNameIterator.Value}]
									break
								Case AutoTransmute
									AutoTransmute:Set[${BuyNameIterator.Value}]
									break
								Case CraftItem
									CraftItem:Set[${BuyNameIterator.Value}]
									break
								Case Stack
									CraftStack:Set[${BuyNameIterator.Value}]
									break
								Case Stock
									CraftMinTotal:Set[${BuyNameIterator.Value}]
									break
								Case Recipe
									CraftRecipe:Set[${BuyNameIterator.Value}]
									break
								Case BuyNameOnly
									BuyNameOnly:Set[${BuyNameIterator.Value}]
									break
								Case StartLevel
									startlevel:Set[${BuyNameIterator.Value}]
									break
								Case EndLevel
									endlevel:Set[${BuyNameIterator.Value}]
									break
								Case Tier
									tier:Set[${BuyNameIterator.Value}]
									break
								Case Box
									box:Set[${BuyNameIterator.Value}]
									break
							}
						}
						while ${BuyNameIterator:Next(exists)}

						; run the routine to scan and buy items if we still need more bought
						
						if ${BuyNumber} > 0 && ${tabname.Equal["Buy"]}
						{
							Call CheckFocus
							call BuyItems "${BuyIterator.Key}" ${BuyPrice} ${BuyNumber} ${Harvest} ${BuyNameOnly} ${BuyAttuneOnly} ${AutoTransmute} ${startlevel} ${endlevel} ${tier}
							; Pause or quit pressed then exit the routine
							ExecuteQueued
							Waitframe
							if ${Exitmyprices} || ${Pausemyprices}
							{
								Return
							}
						}
						; Or if the paramaters are Craft and init then scan and place the entries in the craft tab
						elseif ${action.Equal["init"]} && ${tabname.Equal["Craft"]}
						{
							if ${CraftItem}
							{
								UIElement[ItemList@Craft@GUITabs@MyPrices]:AddItem["${BuyIterator.Key}"]
							}
						}
						elseif ${action.Equal["place"]}
						{
							 if ${CraftItem}
							 {
								Call CheckFocus
								call placeitem "${BuyIterator.Key}" ${box}
							 }
						}
						elseif ${action.Equal["scan"]} && ${tabname.Equal["Craft"]}
						{
							; if the item is marked as a craft one then check if the Minimum broker total has been reached
							if ${CraftItem}
							{
								call checktotals "${BuyIterator.Key}" ${CraftStack} ${CraftMinTotal} "${CraftRecipe}"
							}
						}
					}
				}
			}
			; Keep looping till you've read all the Items listed under the ${tabname} Sub-Set
			while ${NameIterator:Next(exists)}
		}
		; Keep looping till you've read all the items in the Top level sets
		While ${BuyIterator:Next(exists)}
	}

	UIElement[Errortext@Sell@GUITabs@MyPrices]:SetText[" ** Finished **"]

	call echolog "<end> : buy"
}

; check to see if we need to make more craftable items to refil our broker stocks
function checktotals(string itemname, int stacksize, int minlimit, string Recipe)
{
	call echolog "-> checktotals ${itemname} ${stacksize} ${minlimit} ${Recipe}"
	; totals set (unsaved)
	LavishSettings:AddSet[craft]
	LavishSettings[craft]:AddSet[CraftItem]

	Declare Totals int 0 local
	Declare Makemore int 0 local

	CraftList:Set[${LavishSettings[craft].FindSet[CraftItem]}]

	if ${CraftList.FindSetting[${itemname}](exists)}
	{
		Totals:Set[${CraftList.FindSetting[${itemname}]}]

	}
	else
	{
		Totals:Set[0]
	}
	
	if ${Totals} < ${minlimit}
		{
			Makemore:Set[${Math.Calc[(${minlimit}-${Totals})/${stacksize}]}]
		}
	if ${Makemore}>0
		{
			call AddLog "you need to make ${Makemore} more stacks of ${itemname}" FFCCFFCC
			; if an alternative recipe name is there then use that otherwise use the item name
			if ${Recipe.Equal[NULL]} || ${Recipe.Length} == 0
			{
				call addtocraft "${itemname}" ${Makemore}
			}
			else
			{
				call addtocraft "${Recipe}" ${Makemore}
			}
		}
	call echolog "<end> : checktotals "
}

; update the user file from craft to include a favourite called myprices
; this set will contain all the items that have a totals shortfall
function addtocraft(string itemname, int Makemore)
{
	call echolog "-> addtocraft ${itemname} ${Makemore}"

	CraftItemList:Set[${LavishSettings[newcraft].FindSet[Recipe Favourites]}]

	CraftItemList:AddSet[_myprices]

	CraftList:Set[${CraftItemList.FindSet[_myprices]}]

	CraftList:AddSetting[${itemname},${Makemore}]

	LavishSettings[newcraft]:Export[${CraftPath}${Me.Name}.xml]
	call echolog "<end> : addtocraft"
}

function BuyItems(string BuyName, float BuyPrice, int BuyNumber, bool Harvest, bool BuyNameOnly, bool BuyAttuneOnly, bool AutoTransmute, int startlevel, int endlevel, int tier)
{
	call echolog "-> BuyItems ${BuyName} ${BuyPrice} ${BuyNumber} ${Harvest} ${BuyNameOnly} ${BuyAttuneOnly} ${AutoTransmute} ${startlevel} ${endlevel} ${tier}"

	Declare CurrentPage int 1 local
	Declare CurrentItem int 1 local
	Declare FinishBuy bool local
	Declare BrokerNumber int local
	Declare BrokerPrice float local
	Declare TryBuy int local
	Declare StopSearch bool FALSE local
	Declare MyCash float local
	Declare OldCash float local
	Declare BoughtNumber int local
	Declare MaxBuy int local
	Declare CurrentQuantity int local
	Declare StackBuySize int local

	Declare namesearch string local
	Declare startsearch string local
	Declare endsearch string local
	Declare tiersearch string local
	Declare costsearch string local

	if  ${BuyNameOnly}
	{
		call echolog "searchbrokerlist "${BuyName}" 0 0 0 ${Math.Calc[${BuyPrice} * 100]}"
		call searchbrokerlist "${BuyName}" 0 0 0 ${Math.Calc[${BuyPrice} * 100]}
	}
	else
	{
		call echolog "<BuyItems> call searchbrokerlist "${BuyName}" ${startlevel} ${endlevel} ${tier} ${Math.Calc[${BuyPrice} * 100]} ${BuyAttuneOnly}"
		call searchbrokerlist "${BuyName}" ${startlevel} ${endlevel} ${tier} ${Math.Calc[${BuyPrice} * 100]} ${BuyAttuneOnly}
	}

	Call echolog "<BuyItems> Call BrokerSearch ${BuyName}"

	; scan to make sure the item is listed and get lowest price
	Call BrokerSearch "${BuyName}" ${BuyNameOnly}
	
	; if items listed on the broker
	if ${Return} != -1
	{
		; Scan the broker list one by one buying the items until the end of the list is reached or all the Number wanted have been bought
		do
		{
			if ${InventorySlotsFree}<=0
			{
				Echo Out of Inventory Space!
				Break
			}
			
			Vendor:GotoSearchPage[${CurrentPage}]
			wait 5
			do
			{
				; calculate how much coin this character has on it
				MyCash:Set[${Math.Calc[(${Me.Platinum}*10000)+(${Me.Gold}*100)+(${Me.Silver})+(${Me.Copper}/100)]}]
				; How many items for sale on the current broker entry
				BrokerNumber:Set[${Vendor.Broker[${CurrentItem}].Quantity}]
				; How much each single item costs
				BrokerPrice:Set[${Vendor.Broker[${CurrentItem}].Price}]

				; if it's more than I want to pay then stop
				if ${BrokerPrice} > ${BuyPrice}
				{
					StopSearch:Set[TRUE]
					break
				}
				
				; if there are items available (sometimes broker number shows 0 available when someone beats you to it)
				if ${BrokerNumber} >0
				{
					do
					{
						BrokerNumber:Set[${Vendor.Broker[${CurrentItem}].Quantity}]

						if ${BrokerNumber} == 0
						{
							break
						}
						

						; if the broker entry being looked at shows more items than we want then buy what we want
						if ${BrokerNumber} > ${BuyNumber}
						{
							TryBuy:Set[${BuyNumber}]
						}
						else
						{
							; otherwise buy whats there

							TryBuy:Set[${BrokerNumber}]
						}
						; check you can afford to buy the items
						call checkcash ${BrokerPrice} ${TryBuy} ${Harvest}
						; buy what you can afford
						if ${Return} > 0
						{
							StackBuySize:Set[${Return}]
							OldCash:Set[${MyCash}]

							Vendor.Broker[${CurrentItem}]:Buy[${StackBuySize}]

							wait 50 ${Vendor.Item[${CurrentItem}].Quantity} != ${BrokerNumber}
							wait 5

							if ${AutoTransmute}
								Call GoTransmute "${Vendor.Item[${CurrentItem}].Name}"
							
							if ${InventorySlotsFree}<=0
							{
								Echo Out of Inventory Space!
								Break
								StopSearch:Set[TRUE]
							}

							; if unable to buy the required stack due to stack limitations then change to buying singles
							
							if ${Vendor.Item[${CurrentItem}].Quantity} == ${BrokerNumber} && ${Vendor.Item[${CurrentItem}].Quantity} != 0
							{
								; Number on broker not changed ( Buy Singles )
								do
								{
									CurrentQuantity:Set[${Vendor.Item[${CurrentItem}].Quantity}]
									
									Vendor.Item[${CurrentItem}]:Buy[1]  
									wait 50 ${Vendor.Item[${CurrentItem}].Quantity} != ${CurrentQuantity}
									wait 5
									
									if ${AutoTransmute}
										Call GoTransmute "${Vendor.Item[${CurrentItem}].Name}"

									ExecuteQueued
									Waitframe

									if ${InventorySlotsFree}<=0
									{
										Echo Out of Inventory Space!
										Break
										StopSearch:Set[TRUE]
									}

									if ${Exitmyprices} || ${Pausemyprices}
									{
										break
									}
								}
								while ${StackBuySize:Dec} >= 0 && ${Vendor.Item[${CurrentItem}].Quantity} != 0
			
							}
							
							MyCash:Set[${Math.Calc[(${Me.Platinum}*10000)+(${Me.Gold}*100)+(${Me.Silver})+(${Me.Copper}/100)]}]
							; check you have actually bought an item
							call checkbought ${BrokerPrice} ${OldCash} ${MyCash}
							BoughtNumber:Set[${Return}]
							; reduce the number left to buy
							BuyNumber:Set[${Math.Calc[${BuyNumber}-${BoughtNumber}]}]
							call StringFromPrice ${BrokerPrice}
							call AddLog "Bought (${BoughtNumber}) ${BuyName} at ${Return}" FF00FF00
						}
						else
						{
							; if you can't afford any then stop scanning
							StopSearch:Set[TRUE]
							break
						}
						
						ExecuteQueued
						Waitframe
						if ${Exitmyprices} || ${Pausemyprices}
						{
							break
						}

					}
					While ${BrokerNumber} > 0 && ${BuyNumber} > 0
				}
				if ${StopSearch}
				{
					break
				}
				
				ExecuteQueued
				WaitFrame
				if ${Exitmyprices} || ${Pausemyprices}
				{
					break
				}
			}
			while ${CurrentItem:Inc}<=${Vendor.NumItemsForSale} && ${BuyNumber} > 0 && !${Exitmyprices} && !${Pausemyprices} && !${StopSearch}
			CurrentItem:Set[1]
			
			ExecuteQueued
			Waitframe
			if ${Exitmyprices} || ${Pausemyprices}
			{
				break
			}
		}
		; keep going till all items listed have been scanned and bought or you have reached your limit
		while ${CurrentPage:Inc}<=${Vendor.TotalSearchPages} && ${BuyNumber} > 0 && !${Exitmyprices} && !${Pausemyprices} && !${StopSearch}

		; now we've bought all that are available , save the number we've still got left to buy
		call Saveitem Buy "${BuyName}" ${BuyPrice} 0 ${BuyNumber} ${Harvest} ${BuyNameOnly} ${BuyAttuneOnly} ${AutoTransmute} ${startlevel} ${endlevel} ${tier}
	}
	call echolog "<end> : BuyItems"
}

; function to check you actually bought an item (stops false positives if someone beats you to it or someone removes an item before you can buy it)

function checkbought(float BrokerPrice, float OldCash, float NewCash)
{
	call echolog "-> checkbought Broker Price : ${BrokerPrice} My Old Cash : ${OldCash} My Current cash : ${NewCash}"
	
	Declare Diff float local
	Declare DiffInt int local

	; find out how much was spent
	Diff:Set[${Math.Calc[${OldCash}-${NewCash}]}]

	; Find out how many were bought
	Diff:Set[${Math.Calc[${Diff}/${BrokerPrice}]}]

	; Check for partial amounts due to rounding errors in math calculations

	If ${Diff} > 1
	{
		DiffInt:Set[${Diff}]
		If ${Math.Calc[${Diff}-${DiffInt}]} > 0.5
		{
			DiffInt:Inc
		}
		call echolog "<- checkbought ${DiffInt}"
		return ${DiffInt}
	}
	else
	{
		call echolog "<- checkbought 1"
		Return 1
	}

}

; check to see if you have enough coin on your character to buy the number you want to,
; if not then calculate how many you CAN buy with the coin you have.

function checkcash(float Buyprice, int Buynumber, bool Harvest)
{
	call echolog  "-> checkcash: BuyPrice : ${Buyprice} Buy Number : ${Buynumber} Harvest : ${Harvest}"

	Declare NewBuyNumber int 0 local
	Declare MyCash float local
	Declare MaxNumber int 100 local

	; calculate how much coin this character has on it
	MyCash:Set[${Math.Calc[(${Me.Platinum}*10000)+(${Me.Gold}*100)+(${Me.Silver})+(${Me.Copper}/100)]}]

	; if set limit based on harvest or non-harvest

	if ${Harvest}
	{
		MaxNumber:Set[200]
	}
	else
	{
		MaxNumber:Set[100]
	}

	if ${Buynumber} > ${MaxNumber}
	{
		Buynumber:Set[${MaxNumber}]
	}

	if ${Math.Calc[(${Buyprice}*${Buynumber})]} > ${MyCash}
	{
		NewBuyNumber:Set[${Math.Calc[${MyCash}/${Buyprice}]}]
		call echolog "<- checkcash ${NewBuyNumber}"
		return ${NewBuyNumber}
	}
	else
	{
		call echolog "<- checkcash ${Buynumber}"
		return ${Buynumber}
	}
}

; Scan the broker when an item is clicked on in the BUY item list.

function ClickBrokerSearch(string tabtype, int ItemID)
{
	call echolog "-> ClickBrokerSearch ${tabtype} ${ItemID}"

	Declare LBoxString string local
	Declare startlevel int local
	Declare endlevel int local
	Declare tier int local
	Declare cost int local
	Declare pp int local
	Declare gp int local
	Declare sp int local
	Declare cp int local
	
	; scan the broker for the item clicked on in the list
	LBoxString:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[${tabtype}].FindChild[ItemList].Item[${ItemID}]}]

	If ${tabtype.Equal["Buy"]}
	{
		startlevel:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[StartLevel].Text}]
		endlevel:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[EndLevel].Text}]
		tier:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[Tier].Selection}]
		pp:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[MinPlatPrice].Text}]
		gp:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[MinGoldPrice].Text}]
		sp:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[MinSilverPrice].Text}]
		cp:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[MinCopperPrice].Text}]
		cost:Set[${Math.Calc[${pp}*1000000]}]
		cost:Set[${Math.Calc[${cost}+(${gp}*10000)]}]
		cost:Set[${Math.Calc[${cost}+(${sp}*100)]}]
		cost:Set[${Math.Calc[${cost}+${cp}]}]

		if ${UIElement[BuyNameOnly@Buy@GUITabs@MyPrices].Checked}
		{
			call searchbrokerlist "${LBoxString}" 0 0 0  ${cost}
			; broker Name "${LBoxString}" Sort ByPriceAsc MaxLevel 999
		}
		else
		{
			
			call searchbrokerlist "${LBoxString}" ${startlevel} ${endlevel} ${tier} ${cost} ${UIElement[BuyAttuneOnly@Buy@GUITabs@MyPrices].Checked}
		}
	}
	else
	{
		broker Name "${LBoxString}" Sort ByPriceAsc MaxLevel 999
	}
	call echolog "<end> : ClickBrokerSearch"

}


function searchbrokerlist(string LBoxString, int startlevel, int endlevel, int tier, float cost, bool BuyAttuneOnly)
{

	call echolog "-> searchbrokerlist ${LBoxString} , ${startlevel} , ${endlevel} , ${tier} , ${cost} ${BuyAttuneOnly}"

	Declare namesearch string local
	Declare startsearch string local
	Declare endsearch string local
	Declare tiersearch string local
	Declare costsearch string local
	Declare attunesearch string local

	if !${LBoxString.Left[6].Equal[NoName]}
	{
		namesearch:Set[Name "${LBoxString}"]
	}
	if ${startlevel}>0
	{
		startsearch:Set["MinLevel ${startlevel}"]
	}
	if ${endlevel}>0
	{
		endsearch:Set["MaxLevel ${endlevel}"]
	}
	if ${BuyAttuneOnly}
	{
		attunesearch:Set["-Type Attuneable"]
	}
	if ${tier}>0
	{
		Switch "${tier}"
		{
			Case 1
				tiersearch:Set["MinTier Common MaxTier Mythical"]
				break
			Case 2
				tiersearch:Set["MinTier Common MaxTier Common"]
				break
			Case 3
				tiersearch:Set["MinTier Handcrafted MaxTier Handcrafted"]
				break
			Case 4
				tiersearch:Set["MinTier Treasured MaxTier Treasured"]
				break
			Case 5
				tiersearch:Set["MinTier Mastercrafted MaxTier Mastercrafted"]
				break
			Case 6
				tiersearch:Set["MinTier Legendary MaxTier Legendary"]
				break
			Case 7
				tiersearch:Set["MinTier Fabled MaxTier Fabled"]
				break
			Case 8
				tiersearch:Set["MinTier Mythical MaxTier Mythical"]
				break
		}
	}

	costsearch:Set["MaxPrice ${cost}"]

	if ${namesearch.Length}>0
	{
		broker ${namesearch} ${startsearch} ${endsearch} ${tiersearch} ${costsearch} ${attunesearch} Sort ByPriceAsc
	}
	else
	{
		broker ${startsearch} ${endsearch} ${tiersearch} ${costsearch} ${attunesearch} Sort ByPriceAsc
	}
	
	call echolog "<- searchbrokerlist
}	

; Search the broker for items , return the cheapest price found

function BrokerSearch(string lookup, bool BuyNameOnly)
{
	call echolog "-> BrokerSearch ${lookup} ${BuyNameOnly}"
	Declare CurrentPage int 1 local
	Declare CurrentItem int 1 local
	Declare TempMinPrice float -1 local
	Declare stopsearch bool FALSE local
	Declare TempSearch string local
	wait 5
	; check if broker has any listed to compare with your item
	if !${BuyNameOnly}
	{
		if ${Vendor.NumItemsForSale} >0
		{
			Return TRUE
		}
		else
		{
			Return FALSE
		}
	}
	
	if ${Vendor.NumItemsForSale} >0
	{
		; Work through the brokers list page by page
		do
		{
			Vendor:GotoSearchPage[${CurrentPage}]
			CurrentItem:Set[1]
			do
			{
				TempSearch:Set["${Vendor.Broker[${CurrentItem}]}"]
				; check that the items name being looked at is an exact match and not just a partial match
				if ${lookup.Equal["${TempSearch}"]}
				{
					; if checkbox set to ignore broker fee when matching prices
					if ${MatchActual}
					{
						TempMinPrice:Set[${Vendor.Broker[${CurrentItem}].BasePrice}]
					}
					else
					{
						TempMinPrice:Set[${Vendor.Broker[${CurrentItem}].Price}]
					}
					waitframe
					stopsearch:Set[TRUE]
					break
				}
				waitframe
			}
			while ${CurrentItem:Inc}<=${Vendor.NumItemsForSale} && !${stopsearch}
		}
		while ${CurrentPage:Inc}<=${Vendor.TotalSearchPages} && ${TempMinPrice} == -1 && !${stopsearch}
	}
	; Return the Lowest Price Found or -1 if nothing found.
	call echolog "<- BrokerSearch ${TempMinPrice}"
	return ${TempMinPrice}
}


function checkitem(string name)
{
	call echolog "-> checkitem : ${name}"
	; keep a reference directly to the Item set.
	ItemList:Set[${LavishSettings[myprices].FindSet[Item]}]
	Item:Set[${ItemList.FindSet[${name}]}]

	if ${Item.FindSetting[Sell](exists)}
	{
		call echolog "<- checkitem : ${Item.FindSetting[Sell]}"
		return ${Item.FindSetting[Sell]}
	}
	else
	{
		call echolog "<- checkitem : -1"
		return -1
	}
}

function checkmaxitem(string name)
{
	call echolog "-> checkmaxitem : ${name}"
	; keep a reference directly to the Item set.
	ItemList:Set[${LavishSettings[myprices].FindSet[Item]}]
	Item:Set[${ItemList.FindSet[${name}]}]

	if ${Item.FindSetting[MaxPrice](exists)}
	{
		call echolog "<- checkmaxitem : ${Item.FindSetting[MaxPrice]}"
		return ${Item.FindSetting[MaxPrice]}
	}
	else
	{
		call echolog "<- checkmaxitem : -1"
		return -1
	}
}

function LoadList()
{
	call echolog "<start> : Loadlist"
	; clear all totals held in the craft set
	LavishSettings[craft]:Clear

	; keep a reference directly to the Item set.
	ItemList:Set[${LavishSettings[myprices].FindSet[Item]}]

	Declare labelname string local
	Declare Money float local


	UIElement[ItemList@Sell@GUITabs@MyPrices]:ClearItems

	i:Set[1]
	j:Set[1]
	
	; open boxes to refresh broker list data
	do
	{
		if ${Me.Vending[${i}](exists)}
		{
			labelname:Set[${Me.Vending[${i}].Consignment[1]}]
			waitframe
		}
	}
	while ${i:Inc} <= 6

	i:Set[1]
	
	; scan boxes and add items into the list	
	numitems:Set[0]
	do
	{
		if (${Me.Vending[${i}](exists)})  && ${box[${i}]}
		{
			if ${Me.Vending[${i}].CurrentCoin} > 0 && ${TakeCoin}
			{
				Me.Vending[${i}]:TakeCoin
				wait 10
			}
			if ${Me.Vending[${i}].NumItems}>0
			{
				do
				{
					call CheckFocus
					numitems:Inc
					labelname:Set["${Me.Vending[${i}].Consignment[${j}]}"]
					waitframe
					; add the item name onto the sell tab list
					UIElement[ItemList@Sell@GUITabs@MyPrices]:AddItem["${labelname}"]

					; if the item is flagged as a craft item then add the total number on the broker

					if ${ItemList.FindSet[${labelname}].FindSetting[CraftItem]}
					{
						call SetColour ${numitems} FFFFFF00
						call addtotals "${labelname}" ${Me.Vending[${i}].Consignment[${j}].Quantity}
					}
					; store the item name
					itemprice[${numitems}]:Set[${i}]
					; check to see if it already has a minimum price set
					call checkitem "${labelname}"
					Money:Set[${Return}]
					; If no value is returned then add the price to the settings file
					if ${Money} == -1
					{
						call SetColour ${numitems} FF0000FF
						call AddLog "Item Missing from Settings File,  Adding : ${labelname}" FF00CCFF
						call Saveitem Sell "${labelname}" ${Me.Vending[${i}].Consignment[${j}].BasePrice} ${Me.Vending[${i}].Consignment[${j}].BasePrice}
					}
				}
				while ${j:Inc} <= ${Me.Vending[${i}].NumItems}
				waitframe
			}
			j:Set[1]
		}
	}
	while ${i:Inc} <= 6
	call echolog "<end> : Loadlist"
}

; Convert a float price in silver to pp gp sp cp format
function:string StringFromPrice(float Money)
{
	call echolog "-> StringFromPrice ${Money}"
	Declare Platina int local
	Declare Gold int local
	Declare Silver int local
	Declare Copper int local
	Platina:Set[${Math.Calc[${Money}/10000]}]
	Money:Set[${Math.Calc[${Money}-(${Platina}*10000)]}]
	Gold:Set[${Math.Calc[${Money}/100]}]
	Money:Set[${Math.Calc[${Money}-(${Gold}*100)]}]
	Silver:Set[${Money}]
	Money:Set[${Math.Calc[${Money}-${Silver}]}]
	Copper:Set[${Math.Calc[${Money}* 100]}]
	call echolog "<- StringFromPrice ${Platina}pp ${Gold}gp ${Silver}sp ${Copper}cp"
	return ${Platina}pp ${Gold}gp ${Silver}sp ${Copper}cp
}

; Convert a price in pp gp sp cp format to float price in silver

function pricefromstring()
{
	call echolog "<start> pricefromstring"
	Declare itemname string local
	Declare Platina int local
	Declare Gold int local
	Declare Silver int local
	Declare Copper float local
	Declare Money float local
	Declare MaxMoney float local
	Declare Flagged bool local

	itemname:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[Itemname].Text}]
	if ${itemname.Length} == 0
	{
		AddLog "Try Selecting something first!!" FFFF0000
	}
	else
	{
		; Read the values held in the GUI boxes
		Platina:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[MinPlatPrice].Text}]
		Gold:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[MinGoldPrice].Text}]
		Silver:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[MinSilverPrice].Text}]
		Copper:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[MinCopperPrice].Text}]

		; calclulate the value in silver
		call calcsilver ${Platina} ${Gold} ${Silver} ${Copper}
		Money:Set[${Return}]
		
		; Read the values held in the GUI boxes
		Platina:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[MaxPlatPrice].Text}]
		Gold:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[MaxGoldPrice].Text}]
		Silver:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[MaxSilverPrice].Text}]
		Copper:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[MaxCopperPrice].Text}]

		; calclulate the value in silver
		call calcsilver ${Platina} ${Gold} ${Silver} ${Copper}
		MaxMoney:Set[${Return}]

		; Save the new value in your settings file
		call Saveitem Sell "${itemname}" ${Money} ${MaxMoney} 0 ${UIElement[CraftItem@Sell@GUITabs@MyPrices].Checked}
		
		; Read the values held in the GUI boxes
		Platina:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[PlatPrice].Text}]
		Gold:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[GoldPrice].Text}]
		Silver:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[SilverPrice].Text}]
		Copper:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[CopperPrice].Text}]

		; calclulate the value in silver
		call calcsilver ${Platina} ${Gold} ${Silver} ${Copper}
		MaxMoney:Set[${Return}]
		
		; Find where the Item is stored in the container
		call FindItem ${itemprice[${ClickID}]} "${itemname}"
		j:Set[${Return}]
		; set the current price
		if ${j} > -1
		{
			call SetItemPrice ${itemprice[${ClickID}]} ${j} ${MaxMoney}
			call ClickBrokerSearch Sell ${ClickID}
		}
	}
	call echolog "<end> : pricefromstring"
}

function calcsilver(int plat, int gold, int silver, float copper)
{
	Declare Platina int local
	Declare Gold int local
	Declare Silver int local
	Declare Copper float local
	Declare SMoney float local
	
	Platina:Set[${Math.Calc[${plat}*10000]}]
	Gold:Set[${Math.Calc[${gold}*100]}]
	Copper:Set[${Math.Calc[${copper}/100]}]
	SMoney:Set[${Math.Calc[${Platina}+${Gold}+${silver}+${Copper}]}]
	
	Return ${SMoney} 
}

; routine to save/update items and prices

function Saveitem(string Saveset, string ItemName, float Money, float MaxMoney, int Number, bool flagged, bool nameonly, bool attuneable, bool autotransmute, int startlevel, int endlevel, int tier, int boxnumber, string Recipe)
{
	call echolog "-> Saveitem ${Saveset} ${ItemName} ${Money} ${Number} ${flagged} ${nameonly} ${attuneable} ${autotransmute} ${startlevel} ${endlevel} ${tier} ${Recipe}"
	if ${Saveset.Equal["Sell"]} || ${Saveset.Equal["Craft"]}
	{
		ItemList:Set[${LavishSettings[myprices].FindSet[Item]}]
	}
	Else
	{
		ItemList:Set[${LavishSettings[myprices].FindSet[Buy]}]
	}

	ItemList:AddSet[${ItemName}]

	Item:Set[${ItemList.FindSet[${ItemName}]}]
	
	if ${Saveset.Equal["Sell"]}
	{
		; Clear all previous information
		; ItemList[${ItemName}]:Clear

		Item:AddSetting[${Saveset},${Money}]
		if ${UIElement[MinPrice@Sell@GUITabs@MyPrices].Checked}
		{
			Item:AddSetting[MinSalePrice,TRUE]
		}
		else
		{
			Item:AddSetting[MinSalePrice,FALSE]
		}
		if ${UIElement[MaxPrice@Sell@GUITabs@MyPrices].Checked}
		{
			Item:AddSetting[MaxSalePrice,TRUE]
			Item:AddSetting[MaxPrice,${MaxMoney}]
		}
		else
		{
			Item:AddSetting[MaxSalePrice,FALSE]
		}
		if ${flagged}
		{
			Item:AddSetting[CraftItem,TRUE]
		}
		else
		{
			Item:AddSetting[CraftItem,FALSE]
		}
	}
	elseif ${Saveset.Equal["Craft"]}
	{
		Item:AddSetting[Stack,${Money}]
		Item:AddSetting[Stock,${Number}]
		if ${Recipe.Length} == 0
		{
			Item:AddSetting[Recipe,${ItemName}]
		}
		else
		{
			Item:AddSetting[Recipe,${Recipe}]
		}
		Item:AddSetting[CraftItem,TRUE]
		Item:AddSetting[Box,${boxnumber}]
	}
	elseif ${Saveset.Equal["Buy"]}
	{
		; Clear all previous information
		ItemList[${ItemName}]:Clear

		Item:AddSetting[BuyNumber,${Number}]
		Item:AddSetting[BuyPrice,${Money}]
		if ${flagged}
		{
			Item:AddSetting[Harvest,TRUE]
		}
		else
		{
			Item:AddSetting[Harvest,FALSE]
		}
		if ${nameonly}
		{
			Item:AddSetting[Buynameonly,TRUE]
		}
		else
		{
			Item:AddSetting[BuyNameOnly,FALSE]
			Item:AddSetting[StartLevel,${startlevel}]
			Item:AddSetting[EndLevel,${endlevel}]
			Item:AddSetting[Tier,${tier}]
		}

		if ${attuneable}
			Item:AddSetting[BuyAttuneOnly,TRUE]

		if ${autotransmute}
			Item:AddSetting[AutoTransmute,TRUE]
	}

	LavishSettings[myprices]:Export[${XMLPath}${Me.Name}_MyPrices.XML]
	call echolog "<end> : Saveitem"
}


; routine to update the myprices settings

function SaveSetting(string Settingname, string Value)
{
	call echolog "-> SaveSetting ${Settingname} ${Value}"
	General:Set[${LavishSettings[myprices].FindSet[General]}]
	General:AddSetting[${Settingname},${Value}]
	call echolog "<end> : SaveSetting"
}

; changes the color of the items in the listbox

function SetColour(int position, string colour)
{
	UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[ItemList].Item[${position}]:SetTextColor[${colour}]
	return
}

; update the boxes in the Sell tab with the right values

function FillMinPrice(int ItemID)
{
	call echolog "-> FillMinPrice ${ItemID}"
	Declare LBoxString string local
	Declare Money float local
	Declare Platina int local
	Declare Gold int local
	Declare Silver int local
	Declare Copper int local
	Declare ItemName string local
	Declare j int local
	Declare CraftItem bool local

	; Put the values in the right boxes.

	; Display the current price
	LBoxString:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Sell].FindChild[ItemList].Item[${ItemID}]}]

	call FindItem ${itemprice[${ItemID}]} "${LBoxString}"
	j:Set[${Return}]

	if ${j} != -1
	{
		ItemName:Set[${Me.Vending[${itemprice[${ItemID}]}].Consignment[${j}].Name}]

		UIElement[Itemname@Sell@GUITabs@MyPrices]:SetText[${LBoxString}]

		; Display your current Price for that Item

		Money:Set[${Me.Vending[${itemprice[${ItemID}]}].Consignment[${j}].BasePrice}]

		Platina:Set[${Math.Calc[${Money}/10000]}]
		Money:Set[${Math.Calc[${Money}-(${Platina}*10000)]}]
		Gold:Set[${Math.Calc[${Money}/100]}]
		Money:Set[${Math.Calc[${Money}-(${Gold}*100)]}]
		Silver:Set[${Money}]
		Money:Set[${Math.Calc[${Money}-${Silver}]}]
		Copper:Set[${Math.Calc[${Money}* 100]}]

		UIElement[PlatPrice@Sell@GUITabs@MyPrices]:SetText[${Platina}]
		UIElement[GoldPrice@Sell@GUITabs@MyPrices]:SetText[${Gold}]
		UIElement[SilverPrice@Sell@GUITabs@MyPrices]:SetText[${Silver}]
		UIElement[CopperPrice@Sell@GUITabs@MyPrices]:SetText[${Copper}]


		; Display your minimum price for the item

		LavishSettings:AddSet[myprices]
		LavishSettings[myprices]:AddSet[General]
		LavishSettings[myprices]:AddSet[Item]

		ItemList:Set[${LavishSettings[myprices].FindSet[Item]}]
		ItemList:AddSet[${ItemName}]

		Item:Set[${ItemList.FindSet[${LBoxString}]}]
		Money:Set[${Item.FindSetting[Sell]}]

		CraftItem:Set[${Item.FindSetting[CraftItem]}]

		if ${CraftItem}
		{
			UIElement[CraftItem@Sell@GUITabs@MyPrices]:SetChecked
		}
		else
		{
			UIElement[CraftItem@Sell@GUITabs@MyPrices]:UnsetChecked
		}

		if !${Item.FindSetting[MinSalePrice]}
		{
			UIElement[MinPlatPrice@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MinPlatPrice@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MinGoldPrice@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MinSilverPrice@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MinCopperPrice@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MinPlatPriceText@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MinGoldPriceText@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MinSilverPriceText@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MinCopperPriceText@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[label2@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MinPrice@Sell@GUITabs@MyPrices]:UnsetChecked
		}
		else
		{
			UIElement[MinPlatPrice@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MinPlatPrice@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MinGoldPrice@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MinSilverPrice@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MinCopperPrice@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MinPlatPriceText@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MinGoldPriceText@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MinSilverPriceText@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MinCopperPriceText@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[label2@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MinPrice@Sell@GUITabs@MyPrices]:SetChecked
		}

		Platina:Set[${Math.Calc[${Money}/10000]}]
		Money:Set[${Math.Calc[${Money}-(${Platina}*10000)]}]
		Gold:Set[${Math.Calc[${Money}/100]}]
		Money:Set[${Math.Calc[${Money}-(${Gold}*100)]}]
		Silver:Set[${Money}]
		Money:Set[${Math.Calc[${Money}-${Silver}]}]
		Copper:Set[${Math.Calc[${Money}*100]}]

		UIElement[MinPlatPrice@Sell@GUITabs@MyPrices]:SetText[${Platina}]
		UIElement[MinGoldPrice@Sell@GUITabs@MyPrices]:SetText[${Gold}]
		UIElement[MinSilverPrice@Sell@GUITabs@MyPrices]:SetText[${Silver}]
		UIElement[MinCopperPrice@Sell@GUITabs@MyPrices]:SetText[${Copper}]

		Money:Set[${Item.FindSetting[MaxPrice]}]
		
		if !${Item.FindSetting[MaxSalePrice]}
		{
			UIElement[MaxPlatPrice@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MaxPlatPrice@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MaxGoldPrice@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MaxSilverPrice@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MaxCopperPrice@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MaxPlatPriceText@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MaxGoldPriceText@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MaxSilverPriceText@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MaxCopperPriceText@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[label3@Sell@GUITabs@MyPrices]:SetAlpha[0.1]
			UIElement[MaxPrice@Sell@GUITabs@MyPrices]:UnsetChecked
		}
		else
		{
			UIElement[MaxPlatPrice@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MaxPlatPrice@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MaxGoldPrice@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MaxSilverPrice@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MaxCopperPrice@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MaxPlatPriceText@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MaxGoldPriceText@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MaxSilverPriceText@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MaxCopperPriceText@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[label3@Sell@GUITabs@MyPrices]:SetAlpha[1]
			UIElement[MaxPrice@Sell@GUITabs@MyPrices]:SetChecked
		}

		Platina:Set[${Math.Calc[${Money}/10000]}]
		Money:Set[${Math.Calc[${Money}-(${Platina}*10000)]}]
		Gold:Set[${Math.Calc[${Money}/100]}]
		Money:Set[${Math.Calc[${Money}-(${Gold}*100)]}]
		Silver:Set[${Money}]
		Money:Set[${Math.Calc[${Money}-${Silver}]}]
		Copper:Set[${Math.Calc[${Money}*100]}]

		UIElement[MaxPlatPrice@Sell@GUITabs@MyPrices]:SetText[${Platina}]
		UIElement[MaxGoldPrice@Sell@GUITabs@MyPrices]:SetText[${Gold}]
		UIElement[MaxSilverPrice@Sell@GUITabs@MyPrices]:SetText[${Silver}]
		UIElement[MaxCopperPrice@Sell@GUITabs@MyPrices]:SetText[${Copper}]
		

	}

	call echolog "<end> : FillMinPrice"
}

function CheckMinPriceSet(string itemname)
{
	call echolog "-> CheckMinPriceSet ${itemname}"
	LavishSettings:AddSet[myprices]
	LavishSettings[myprices]:AddSet[General]
	LavishSettings[myprices]:AddSet[Item]

	ItemList:Set[${LavishSettings[myprices].FindSet[Item]}]
	ItemList:AddSet[${itemName}]

	Item:Set[${ItemList.FindSet[${itemname}]}]
	call echolog "<- CheckMinPriceSet ${Item.FindSetting[MinSalePrice]}"
	return ${Item.FindSetting[MinSalePrice]}
}

function CheckMaxPriceSet(string itemname)
{
	call echolog "-> CheckMaxPriceSet ${itemname}"
	LavishSettings:AddSet[myprices]
	LavishSettings[myprices]:AddSet[General]
	LavishSettings[myprices]:AddSet[Item]

	ItemList:Set[${LavishSettings[myprices].FindSet[Item]}]
	ItemList:AddSet[${itemName}]

	Item:Set[${ItemList.FindSet[${itemname}]}]
	call echolog "<- CheckMaxPriceSet ${Item.FindSetting[MaxSalePrice]}"
	return ${Item.FindSetting[MaxSalePrice]}
}

function savebuyinfo()
{
	call echolog "<start> : savebuyinfo"
	Declare itemname string local
	Declare itemnumber int local
	Declare Platina int local
	Declare Gold int local
	Declare Silver int local
	Declare Copper float local
	Declare Money float local
	Declare tier int local
	Declare startlevel int local
	Declare endlevel int local

	itemname:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[BuyName].Text}]
	itemnumber:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[BuyNumber].Text}]
	Platina:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[MinPlatPrice].Text}]
	Gold:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[MinGoldPrice].Text}]
	Silver:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[MinSilverPrice].Text}]
	Copper:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[MinCopperPrice].Text}]
	startlevel:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[startlevel].Text}]
	endlevel:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[endlevel].Text}]
	tier:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[tier].Selection}]
	
	if ${itemname.Length} == 0 && !${UIElement[BuyNameOnly@Sell@GUITabs@MyPrices].Checked}
	{
		itemname:Set["NoName S: ${startlevel} E: ${endlevel} T : ${tier}"]
	}

	; calclulate the value in silver
	Platina:Set[${Math.Calc[${Platina}*10000]}]
	Gold:Set[${Math.Calc[${Gold}*100]}]
	Copper:Set[${Math.Calc[${Copper}/100]}]
	Money:Set[${Math.Calc[${Platina}+${Gold}+${Silver}+${Copper}]}]

	; check information was entered in all boxes and save
	if ${itemname.Length} == 0
	{
		UIElement[ErrorText@Buy@GUITabs@MyPrices]:SetText[No item name entered]
	}
	elseif ${itemnumber} < 0
	{
		UIElement[ErrorText@Buy@GUITabs@MyPrices]:SetText[Try setting a valid number of items]
	}
	elseif ${Money} <= 0
	{
		UIElement[ErrorText@Buy@GUITabs@MyPrices]:SetText[You haven't set a price to buy from]
	}
	else
	{
		UIElement[ErrorText@Buy@GUITabs@MyPrices]:SetText[Saving Information]
		call Saveitem Buy "${itemname}" ${Money} 0 ${itemnumber} ${UIElement[Harvest@Buy@GUITabs@MyPrices].Checked} ${UIElement[BuyNameOnly@Buy@GUITabs@MyPrices].Checked} ${UIElement[BuyAttuneOnly@Buy@GUITabs@MyPrices].Checked} ${UIElement[Transmute@Buy@GUITabs@MyPrices].Checked} ${startlevel} ${endlevel} ${tier}
		call buy Buy init
	}
	call echolog "<end> : savebuyinfo"
}

function savecraftinfo()
{
	call echolog "<start> : savecraftinfo"
	Declare CraftName string local
	Declare RecipeName string local
	Declare CraftStack int local
	Declare CraftNumber int local
	Declare BoxNumber int local

	CraftName:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Craft].FindChild[CraftName].Text}]
	RecipeName:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Craft].FindChild[RecipeName].Text}]
	CraftStack:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Craft].FindChild[CraftStack].Text}]
	CraftNumber:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Craft].FindChild[CraftNumber].Text}]
	BoxNumber:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Craft].FindChild[BoxNumber].Text}]

	; check information was entered in all boxes and save

	if ${CraftName.Length} == 0
	{
		UIElement[ErrorText@Craft@GUITabs@MyPrices]:SetText[No item selected]
	}
	elseif ${CraftStack} <= 0
	{
		UIElement[ErrorText@Craft@GUITabs@MyPrices]:SetText[Try setting a valid Craft Stack size]
	}
	elseif ${CraftNumber} <= 0
	{
		UIElement[ErrorText@Craft@GUITabs@MyPrices]:SetText[Try setting a valid Stock Limit]
	}
	elseif !${Me.Vending[${BoxNumber}](exists)} || ${BoxNumber} == 0
	{
		UIElement[ErrorText@Craft@GUITabs@MyPrices]:SetText[Try setting a valid Box Number]
	}
	else
	{
		UIElement[ErrorText@Craft@GUITabs@MyPrices]:SetText[Saving Information]
	; Parameters : Craft , Itemname , Stackszie , Number , <Bool> Craftitem, <Bool> nameonly,<bool>, attune only <bool>, transmute startlevel,endlevel,tier, Boxnumber, Recipe Name
		call Saveitem Craft "${CraftName}" ${CraftStack} 0 ${CraftNumber} TRUE TRUE TRUE TRUE 0 0 0 ${BoxNumber} "${RecipeName}"
	}
	call echolog "<end> : savecraftinfo"
}


function deletebuyinfo(int ItemID)
{
	call echolog "-> deletebuyinfo ${ItemID}"
	Declare itemname string local

	itemname:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[Buyname].Text}]

	; find the item Sub-Set and remove it
	BuyList:Set[${LavishSettings[myprices].FindSet[Buy]}]
	BuyList.FindSet["${itemname}"]:Remove

	; save the new information
	LavishSettings[myprices]:Export[${XMLPath}${Me.Name}_MyPrices.XML]
	
	UIElement[ErrorText@Buy@GUITabs@MyPrices]:SetText[Deleting ${itemname}]

	; re-scan and display the new buy list
	call buy Buy init
	call echolog "<end> : deletebuyinfo"
}

; Delete the current item selected in the buybox
function ShowBuyPrices(int ItemID)
{
	call echolog "-> ShowBuyPrices ${ItemID}"
	Declare Money float local
	Declare number int local
	Declare LBoxString string local
	Declare Platina int local
	Declare Gold int local
	Declare Silver int local
	Declare Copper int local
	Declare CraftItem bool local
	Declare Harvest bool local
	Declare startlevel int local
	Declare endlevel int local
	Declare tier int local
	Declare nameonly bool local
	Declare attuneonly bool local
	Declare autotransmute bool local
	
	LBoxString:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Buy].FindChild[ItemList].Item[${ItemID}]}]

	BuyList:Set[${LavishSettings[myprices].FindSet[Buy]}]

	BuyItem:Set[${BuyList.FindSet["${LBoxString}"]}]

	number:Set[${BuyItem.FindSetting[BuyNumber]}]
	Money:Set[${BuyItem.FindSetting[BuyPrice]}]

	startlevel:Set[${BuyItem.FindSetting[StartLevel]}]
	endlevel:Set[${BuyItem.FindSetting[EndLevel]}]
	tier:Set[${BuyItem.FindSetting[Tier]}]

	Platina:Set[${Math.Calc[${Money}/10000]}]
	Money:Set[${Math.Calc[${Money}-(${Platina}*10000)]}]
	Gold:Set[${Math.Calc[${Money}/100]}]
	Money:Set[${Math.Calc[${Money}-(${Gold}*100)]}]
	Silver:Set[${Money}]
	Money:Set[${Math.Calc[${Money}-${Silver}]}]
	Copper:Set[${Math.Calc[${Money}*100]}]

	UIElement[MinPlatPrice@Buy@GUITabs@MyPrices]:SetText[${Platina}]
	UIElement[MinGoldPrice@Buy@GUITabs@MyPrices]:SetText[${Gold}]
	UIElement[MinSilverPrice@Buy@GUITabs@MyPrices]:SetText[${Silver}]
	UIElement[MinCopperPrice@Buy@GUITabs@MyPrices]:SetText[${Copper}]
	UIElement[BuyNumber@Buy@GUITabs@MyPrices]:SetText[${number}]
	UIElement[BuyName@Buy@GUITabs@MyPrices]:SetText[${LBoxString}]

	Harvest:Set[${BuyItem.FindSetting[Harvest]}]
	nameonly:Set[${BuyItem.FindSetting[BuyNameOnly]}]
	attuneonly:Set[${BuyItem.FindSetting[BuyAttuneOnly]}]
	autotransmute:Set[${BuyItem.FindSetting[AutoTransmute]}]

	if ${Harvest}
	{
		UIElement[Harvest@Buy@GUITabs@MyPrices]:SetChecked
	}
	else
	{
		UIElement[Harvest@Buy@GUITabs@MyPrices]:UnsetChecked
	}
	if ${attuneonly}
	{
		UIElement[BuyAttuneOnly@Buy@GUITabs@MyPrices]:SetChecked
	}
	else
	{
		UIElement[BuyAttuneOnly@Buy@GUITabs@MyPrices]:UnsetChecked
	}

	if ${autotransmute}
	{
		UIElement[Transmute@Buy@GUITabs@MyPrices]:SetChecked
	}
	else
	{
		UIElement[Transmute@Buy@GUITabs@MyPrices]:UnsetChecked
	}

	if ${nameonly}
	{
		UIElement[BuyNameOnly@Buy@GUITabs@MyPrices]:SetChecked
		UIElement[StartLevelText@Buy@GUITabs@MyPrices]:Hide
		UIElement[EndLevelText@Buy@GUITabs@MyPrices]:Hide
		UIElement[StartLevel@Buy@GUITabs@MyPrices]:Hide
		UIElement[EndLevel@Buy@GUITabs@MyPrices]:Hide
		UIElement[Tier@Buy@GUITabs@MyPrices]:Hide
	}
	else
	{
		UIElement[BuyNameOnly@Buy@GUITabs@MyPrices]:UnsetChecked
		UIElement[StartLevelText@Buy@GUITabs@MyPrices]:Show
		UIElement[EndLevelText@Buy@GUITabs@MyPrices]:Show
		UIElement[StartLevel@Buy@GUITabs@MyPrices]:Show
		UIElement[EndLevel@Buy@GUITabs@MyPrices]:Show
		UIElement[Tier@Buy@GUITabs@MyPrices]:Show
		UIElement[StartLevel@Buy@GUITabs@MyPrices]:SetText[${startlevel}]
		UIElement[EndLevel@Buy@GUITabs@MyPrices]:SetText[${endlevel}]
		UIElement[Tier@Buy@GUITabs@MyPrices]:SetSelection[${tier}]
	}
	call echolog "<end> : ShowBuyPrices"
}

; Display the details of an item marked as crafted
function ShowCraftInfo(int ItemID)
{
	call echolog "-> ShowCraftInfo ${ItemID}"
	Declare LBoxString string local
	Declare Recipe string local
	Declare Stack int local
	Declare Stock int local
	Declare BoxNumber int local

	LBoxString:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Craft].FindChild[ItemList].Item[${ItemID}]}]

	CraftList:Set[${LavishSettings[myprices].FindSet[Item]}]

	CraftItemList:Set[${CraftList.FindSet["${LBoxString}"]}]

	Recipe:Set[${CraftItemList.FindSetting[Recipe]}]
	Stack:Set[${CraftItemList.FindSetting[Stack]}]
	Stock:Set[${CraftItemList.FindSetting[Stock]}]
	BoxNumber:Set[${CraftItemList.FindSetting[Box]}]

	UIElement[CraftName@Craft@GUITabs@MyPrices]:SetText[${LBoxString}]
	if !${Recipe.Equal[NULL]}
	{
		UIElement[RecipeName@Craft@GUITabs@MyPrices]:SetText[${Recipe}]
	}
	else
	{
		UIElement[RecipeName@Craft@GUITabs@MyPrices]:SetText[${LBoxString}]

	}
	UIElement[CraftStack@Craft@GUITabs@MyPrices]:SetText[${Stack}]
	UIElement[CraftNumber@Craft@GUITabs@MyPrices]:SetText[${Stock}]
	UIElement[BoxNumber@Craft@GUITabs@MyPrices]:SetText[${BoxNumber}]
	call echolog " <end> : ShowCraftInfo"
}

; Toggle an item as 'Non Craftable'
function Unselectcraft(int ItemID)
{
	call echolog "-> Unselectcraft ${ItemID}"

	Declare LBoxString string local

	LBoxString:Set[${UIElement[MyPrices].FindChild[GUITabs].FindChild[Craft].FindChild[CraftName].Text}]
	
	; check information was entered in all boxes and save

	if ${LBoxString.Length} == 0
	{
		UIElement[ErrorText@Craft@GUITabs@MyPrices]:SetText[No item selected]
	}
	else
	{
		CraftList:Set[${LavishSettings[myprices].FindSet[Item]}]
	
		CraftItemList:Set[${CraftList.FindSet["${LBoxString}"]}]
	
		CraftItemList:AddSetting[CraftItem,FALSE]
		
		; save the new information
		LavishSettings[myprices]:Export[${XMLPath}${Me.Name}_MyPrices.XML]
	}
	call echolog " <end> : Unselectcraft"
}


function AddLog(string textline, string colour)
{
	call echolog "** ${textline} **"
	UIElement[ItemList@Log@GUITabs@MyPrices]:AddItem[${textline},1,${colour}]
}

function CheckFocus()
{
	if !${EQ2UIPage[Inventory,Market].IsVisible}
	{
		UIElement[Errortext@Sell@GUITabs@MyPrices]:SetText[" **Paused**"]
		do
		{
			waitframe
		}
		while !${EQ2UIPage[Inventory,Market].IsVisible}
		UIElement[Errortext@Sell@GUITabs@MyPrices]:SetText[" **Processing**"]
	}
	return
}


function SetItemPrice(int i, int j, float price, bool UL)
{
	declare currentitem  string  local
	Call CheckFocus
	currentitem:Set[${Me.Vending[${i}].Consignment[${j}]}]
	call echolog "--------- Set Item Price for ${Me.Vending[${i}].Consignment[${j}]} using Me.Vending[${i}].Consignment[${j}]:SetPrice[${price}]"
	Me.Vending[${i}].Consignment[${j}]:SetPrice[${price}]
	if ${UL}
	{
		call FindItem ${i} "${currentitem}"
		j:Set[${Return}]
		if ${j} != -1
		{
			Me.Vending[${i}].Consignment[${j}]:Unlist
		}
	}
	wait 10
	if ${Logging}
	{
		; check if the item was moved
		call FindItem ${i} "${currentitem}"
		j:Set[${Return}]
		call echolog	"--------- Me.Vending[${i}].Consignment[${j}].BasePrice (${Me.Vending[${i}].Consignment[${j}]}) returned ${Me.Vending[${i}].Consignment[${j}].BasePrice}"
	}
	return
}

objectdef BrokerBot
{
	method LoadUI()
	{
		call echolog "<start> : LoadUI"
		; Load the UI Parts
		;
		ui -reload "${LavishScript.HomeDirectory}/Interface/skins/eq2/EQ2.xml"
		ui -reload -skin eq2 "${MyPricesUIPath}mypricesUI.xml"
		call echolog "<end> : LoadUI"
		return
	}

	method loadsettings()
	{
		; Read settings from The (character name).XML  setting file inside the XML sub-folder
		;
		LavishSettings:AddSet[myprices]
		LavishSettings[myprices]:AddSet[General]
		LavishSettings[myprices]:AddSet[Item]
		LavishSettings[myprices]:AddSet[Buy]

		; set used to integrate craft
		LavishSettings:AddSet[newcraft]
		LavishSettings[newcraft]:AddSet[General Options]
		LavishSettings[newcraft]:AddSet[Recipe Favourites]

		; Non saved set for item totals
		LavishSettings:AddSet[craft]

		ItemList:Set[${LavishSettings[myprices].FindSet[Item]}]

		BuyList:Set[${LavishSettings[myprices].FindSet[Buy]}]

		; make sure nothing from a previous run is in memory
		myprices[ItemList]:Clear
		myprices[BuyList]:Clear
		LavishSettings[craft]:Clear

		;Load settings from that characters file
		LavishSettings[myprices]:Import[${XMLPath}${Me.Name}_MyPrices.XML]

		General:Set[${LavishSettings[myprices].FindSet[General]}]
		Logging:Set[${General.FindSetting[Logging]}]
		MatchLowPrice:Set[${General.FindSetting[MatchLowPrice]}]
		MerchantMatch:Set[${General.FindSetting[MerchantMatch]}]
		IncreasePrice:Set[${General.FindSetting[IncreasePrice]}]
		SetUnlistedPrices:Set[${General.FindSetting[SetUnlistedPrices]}]
		ScanSellNonStop:Set[${General.FindSetting[ScanSellNonStop]}]
		IgnoreCopper:Set[${General.FindSetting[IgnoreCopper]}]
		BuyItems:Set[${General.FindSetting[BuyItems]}]
		SellItems:Set[${General.FindSetting[SellItems]}]
		PauseTimer:Set[${General.FindSetting[PauseTimer]}]
		Craft:Set[${General.FindSetting[Craft]}]
		MatchActual:Set[${General.FindSetting[ActualPrice]}]
		TakeCoin:Set[${General.FindSetting[TakeCoin]}]
		box[1]:Set[${General.FindSetting[box1]}]
		box[2]:Set[${General.FindSetting[box2]}]
		box[3]:Set[${General.FindSetting[box3]}]
		box[4]:Set[${General.FindSetting[box4]}]
		box[5]:Set[${General.FindSetting[box5]}]
		box[6]:Set[${General.FindSetting[box6]}]
		Natural:Set[${General.FindSetting[Natural]}]
		call echolog "Settings being used"
		call echolog "-------------------"
		call echolog "MatchLowPrice is ${MatchLowPrice}"
		call echolog "IncreasePrice is ${IncreasePrice}"
		call echolog "SetUnlistedPrices is ${SetUnlistedPrices}"
		call echolog "ScanSellNonStop is ${ScanSellNonStop}"
		call echolog "IgnoreCopper is ${IgnoreCopper}"
		call echolog "BuyItems is ${BuyItems}"
		call echolog "SellItems is  ${SellItems}"
		call echolog "PauseTimer is ${PauseTimer}"
		call echolog "Craft is ${Craft}"
		call echolog "MatchActual is ${MatchActual}"
		call echolog "TakeCoin is ${TakeCoin}"
		call echolog "box[1] is ${box[1]}"
		call echolog "box[2] is ${box[2]}"
		call echolog "box[3] is ${box[3]}"
		call echolog "box[4] is ${box[4]}"
		call echolog "box[5] is ${box[5]}"
		call echolog "box[6] is ${box[6]}"
		call echolog "Natural is ${Natural}"
		return
	}
}

;search your current broker boxes for existing stacks of items and see if theres room for more
function placeitem(string itemname, int box)
{
	call echolog "<start> placeitem ${itemname} ${box}"
	variable int xvar
	Declare i int local
	Declare space int local
	Declare numitems int local
	Declare maxspaces int local -1
	Declare currenttotal int local
	Declare nospace bool local
	nospace:Set[FALSE]
	storebox:Set[0]

	Me:CreateCustomInventoryArray[nonbankonly]

	call numinventoryitems "${itemname}"
	numitems:Set[${Return}]

	; if there are items to be placed
	if ${numitems} > 0
	{
		if ${box} > 0
		{
			space:Set[${Math.Calc[${Me.Vending[${box}].TotalCapacity}-${Me.Vending[${box}].UsedCapacity}]}]
		}
		if ${box} > 0 && ${space} > 0
		{
			call placeitems "${itemname}" ${box} ${numitems}
			numitems:Set[${Return}]
		}
		else
		{
			i:Set[1]
			do
			{
				; check to see if there is are boxes with the same item in already
				call FindItem ${i} "${itemname}"
				if ${Return} != -1
				{
					; check the box has free space
					space:Set[${Math.Calc[${Me.Vending[${i}].TotalCapacity}-${Me.Vending[${i}].UsedCapacity}]}]
	
					if ${space} > 0
					{
						; place the item into the box
						call placeitems "${itemname}" ${i} ${numitems}
						numitems:Set[${Return}]
					}
				}
			}
			while ${i:Inc} <= 6 && ${numitems} > 0		
		}
		;   place the rest of the items (if any) where there are spaces , boxes with most space first
		if ${numitems} >0
		{
			do
			{
				call boxwithmostspace
				i:Set[${Return}]
				if ${i} == 0
				{
					nospace:Set[TRUE]
					break
				}
				else
				{
					call placeitems "${itemname}" ${i} ${numitems}
					numitems:Set[${Return}]
				}
			}
			while ${numitems}>0 && !${nospace}
		}
	}
	call echolog "<end> placeitem"
}

function placeitems(string itemname, int box, int numitems)
{
	call echolog "<start> placeitems ${itemname} ${box} ${numitems}"
	; attempts to place the items in the defined box
	Declare xvar int local 1
	Declare lasttotal int local
	Declare errorcount int local 0
	Declare space int local
	if ${numitems} >0
	{
		space:Set[${Math.Calc[${Me.Vending[${box}].TotalCapacity}-${Me.Vending[${box}].UsedCapacity}]}]
		call echolog "placing ${numitems} ${itemname} in box ${box}"
		do
		{
			; if an item in your inventory matches the crafted item from your crafted item list
			if ${Me.CustomInventory[${xvar}].Name.Equal[${itemname}]} && !${Me.CustomInventory[${xvar}].Attuned}
			{
				; check current used capacity
				lasttotal:Set[${Me.Vending[${box}].UsedCapacity}]
				; place the item into the consignment system , grouping it with similar items
				Me.CustomInventory[${xvar}]:AddToConsignment[${Me.CustomInventory[${xvar}].Quantity},${box},${Me.Vending[${box}].Consignment[${itemname}].SerialNumber}]

				; make the script wait till the box total has changed (item was added)
				; skips to the next item if nothing changes within 100 frames (one of the items was unplaceable)
				errorcount:Set[0]
				do
				{
					waitframe
				}
				while ${Me.Vending[${box}].UsedCapacity} == ${lasttotal} && ${errorcount:Inc} < 100
				space:Set[${Math.Calc[${Me.Vending[${box}].TotalCapacity}-${Me.Vending[${box}].UsedCapacity}]}]
				numitems:Dec
			}
		}
		while ${xvar:Inc}<=${Me.CustomInventoryArraySize} && ${space} > 0
	}
	call echolog "<end> placeitems ${numitems}"
	return ${numitems}
}

function numinventoryitems(string itemname)
{
	; returns the number of stacks of items in your inventory
	Declare xvar int local 1
	Declare numitems int local 0
	
	do
	{
		if ${Me.CustomInventory[${xvar}].Name.Equal[${itemname}]}
		{
			numitems:Inc
		}
	}
	while ${xvar:Inc}<=${Me.CustomInventoryArraySize}
	return ${numitems}
}

function boxwithmostspace()
{
	; returns the number of the vendor box with the most free space
	Declare i int local 1
	Declare space int local 1
	Declare max int local 0
	do
	{
		space:Set[${Math.Calc[${Me.Vending[${i}].TotalCapacity}-${Me.Vending[${i}].UsedCapacity}]}]
		if ${space} > ${max}
		{
			max:Set[${i}]
		}
	}
	while ${i:Inc} <= 6
	return ${max}
}

function resetscanned()
{
	Declare lcount int local 1
	do
	{
		Scanned[${lcount}]:Set[FALSE]
	}
	While ${lcount:Inc} <= 1000
}

function ChooseNextItem(int numitems)
{
	Declare rnumber int local
	do
	{
		rnumber:Set[${Math.Calc[${Math.Rand[${numitems}]}+1]}]
	}
	While ${Scanned[${rnumber}]}
	return ${rnumber}
}

function GoTransmute(string itemname)
{
	
	Declare numitems int local
	Declare xvar int local 1

	Me:CreateCustomInventoryArray[nonbankonly]
	
	call numinventoryitems "${itemname}"
	numitems:Set[${Return}]
	
	; if the item is in your bags
	if ${numitems} > 0
	{
		do
		{
			; if an item in your inventory matches the name of the item
			if ${Me.CustomInventory[${xvar}].Name.Equal[${itemname}]} && !${Me.CustomInventory[${xvar}].Attuned}
			{
					Me.CustomInventory[${xvar}]:Transmute
					wait 200 ${RewardWindow(exists)}
					RewardWindow:Receive
				break
			}
		}
		while ${xvar:Inc}<=${Me.CustomInventoryArraySize}
	}
}

function StartUp()
{
	Declare tempstring string local
	Declare i int local
	
	tempstring:Set[${Actor[name,a market bulletin board]}]
	if ${tempstring.Length} >4
	{
		Actor[name,a market bulletin board]:DoubleClick
		wait 20
		Actor[${Me}]:DoTarget
		wait 20
		call echolog " * Scanning using Room Board *"
	}
	else
	{
		tempstring:Set[${Actor[Guild,Guild World Market Broker]}]
		if !${tempstring.Equal[NULL]}
		{
			Actor[Guild,Guild World Market Broker]:DoTarget
			wait 10
			Actor[Guild,Guild World Market Broker]:DoubleClick
			wait 20
			call echolog " * Scanning using Guild Hall Broker *"
			echo " * Scanning using Guild Hall Broker *"
		}
		else
		{
			tempstring:Set[${Actor[Guild,broker]}]
			if !${tempstring.Equal[NULL]}
			{
				Actor[Guild,broker]:DoTarget
				wait 10
				Actor[Guild,broker]:DoubleClick
				wait 20
				call echolog " * Scanning using Broker *"
				echo " * Scanning using Broker *"
			}
			else
			{
				Actor[nokillnpc]:DoTarget
				wait 10
				Target:DoubleClick
				wait 20
				call echolog " * Scanning using Nearest Non Agro NPC (Should be broker) *"
			}

		}
	}
	
	i:Set[1]
	do
	{
		if !(${Me.Vending[${i}](exists)})
		{
			UIElement[${i}@Sell@GUITabs@MyPrices]:Hide

		}
	}
	while ${i:Inc} <= 6
	
	call LoadList

	if ${ScanSellNonStop}
	{
		call AddLog "Pausing ${PauseTimer} minutes between scans" FFCC00FF
	}
}

atom(script) EQ2_onInventoryUpdate()
{
	InventorySlotsFree:Set[${Me.InventorySlotsFree}]
}

function echolog(string logline)
{
	if ${Logging}
	{
		Redirect -append "${LogPath}myprices.log" Echo "${logline}"
	}
}


; when the script exits , save all the settings and do some cleaning up
atom atexit()
{
	if !${ISXEQ2.IsReady}
	{
		return
	}
	LavishSettings[myprices]:Export[${XMLPath}${CurrentChar}_MyPrices.XML]
	ui -unload "${MyPricesUIPath}mypricesUI.xml"
	LavishSettings[newcraft]:Clear
	LavishSettings[myprices]:Clear
	LavishSettings[craft]:Clear
}

atom EQ2_onChoiceWindowAppeared()
{
	if !${ChoiceWindow.Text.Find[Are you sure you want to transmute the]}
		return
	if ${ChoiceWindow.Choice1.Find[Accept]}
		ChoiceWindow:DoChoice1
}