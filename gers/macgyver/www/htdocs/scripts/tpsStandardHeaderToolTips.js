		$('.userprofile').qtip
		(
			{
				content: 
				{
					text: '<table style="border-style:none; border-width:0px;"><tr><td>User Name</td><td>Ken Henderson</td></tr><tr><td>User ID</td><td>KeHenderson</td></tr><tr><td>Title</td><td>Merchandising Manager</td></tr></tr></tr><tr><td>Location</td><td>9011-Paradies Support Center</td></tr><tr><td>Department</td><td>000-Merchandising</td></tr><tr><td>Supervisor</td><td>Tony Dudek</td></tr><tr><td>Language</td><td>English(en_US)</td></tr><tr><td colspan=2 style="text-align:center;">IT Information</td></tr><tr><td>IP Address</td><td>172.20.8.221</td></tr><tr><td>Computer Name</td><td>cpltksh01</td></tr><tr><td>Browser</td><td>Internet Explorer v9.0</td></tr><tr><td>Blackberry PIN</td><td>11223344</td></tr></table>',
					title: 
					{
						text : 'Ken Henderson\'s Profile',
						button: 'Close'
					}
				},
				show : { event: 'mouseenter' },
				hide: {	event: false },
				position: 
				{
					viewport: $(window)
				},
				style :
				{
					classes: 'ui-tooltip-blue ui-tooltip-rounded ui-tooltip-shadow'
				}
			}
		);
		$('.tipAccessTPS').qtip
		(
			{
				content: 
				{
					text: 'The AccessTPS site is the corporate intranet site. The site is a collaboration.....',
					title: 
					{
						text: function(api) 
						{
							return $(this).attr('title');
						}
					}
				},
				show : { event: 'mouseenter' },
				hide : { event: 'mouseleave' },
				position: 
				{
					viewport: $(window)
				},
				style :
				{
					classes: 'ui-tooltip-blue ui-tooltip-rounded ui-tooltip-shadow'
				}
			}
		);
		$('.tipMyProfile').qtip
		(
			{
				content: 
				{
					text: 'This is your profile',
					title: 
					{
						text: function(api) 
						{
							return $(this).attr('title');
						}
					}
				},
				show : { event: 'mouseenter' },
				hide : { event: 'mouseleave' },
				position: 
				{
					viewport: $(window)
				},
				style :
				{
					classes: 'ui-tooltip-blue ui-tooltip-rounded ui-tooltip-shadow'
				}
			}
		);
		$('.tipMyParadies').qtip
		(
			{
				content: 
				{
					text: 'My Paradies',
					title: 
					{
						text: function(api) 
						{
							return $(this).attr('title');
						}
					}
				},
				show : { event: 'mouseenter' },
				hide : { event: 'mouseleave' },
				position: 
				{
					viewport: $(window)
				},
				style :
				{
					classes: 'ui-tooltip-blue ui-tooltip-rounded ui-tooltip-shadow'
				}
			}
		);
		$('.tipHelp').qtip
		(
			{
				content: 
				{
					text: 'Talk about Help',
					title: 
					{
						text: function(api) 
						{
							return $(this).attr('title');
						}
					}
				},
				show : { event: 'mouseenter' },
				hide : { event: 'mouseleave' },
				position: 
				{
					viewport: $(window)
				},
				style :
				{
					classes: 'ui-tooltip-blue ui-tooltip-rounded ui-tooltip-shadow'
				}
			}
		);
		$('.tipParadies').qtip
		(
			{
				content: 
				{
					text: 'The Paradies Shops operates more than 500 stores in over 70 airports and hotels across the United States and Canada, serving more than a half-billion customers each year. These stores include original, one-of-a-kind brands unique to individual airports, as well as national brands.<br><br>With roots tracing back to 1960, Paradies is a true pioneer in airport concessions. We were the driving force that moved the industry toward emphasizing value (through the Request for Proposal “RFP” process) over price (bid).<br><br>Diversity and minority representation is important to us. More than half (55 percent) of our over 3,200-member employee family is comprised of people of color, and our company-wide DBE participation rate is 23 percent.<br><br>Our company culture and values distinguish us in the marketplace. We treat our team members, customers and business partners as members of our family, and we pride ourselves on finding ways to exceed expectations on all fronts.',
					title: 
					{
						text: function(api) 
						{
							return $(this).attr('title');
						}
					}
				},
				show : { event: 'mouseenter' },
				hide : { event: 'mouseleave' },
				position: 
				{
					viewport: $(window)
				},
				style :
				{
					classes: 'ui-tooltip-blue ui-tooltip-rounded ui-tooltip-shadow'
				}
			}
		);
		$('.tipHelpDesk').qtip
		(
			{
				content: 
				{
					text: 'Submit a ticket to the help desk for assistance with a technical issue you are experiencing.',
					title: 
					{
						text: function(api) 
						{
							return $(this).attr('title');
						}
					}
				},
				show : { event: 'mouseenter' },
				hide : { event: 'mouseleave' },
				position: 
				{
					viewport: $(window)
				},
				style :
				{
					classes: 'ui-tooltip-blue ui-tooltip-rounded ui-tooltip-shadow'
				}
			}
		);