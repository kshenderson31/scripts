	$('.buttonSubmit').qtip
		(
			{
				content: 
				{
					text: 'Post your changes to the database',
					title: 'Submit'
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
		$('.buttonCancel').qtip
		(
			{
				content: 
				{
					text: 'Cancel the changes you have made, do not save the changes to the database.',
					title: 'Cancel'
				},
				show : { event: 'mouseenter' },
				hide : { event: 'mouseleave', when: 'inactive' },
				position: 
				{
					viewport: $(window)
				},
				style :
				{
					classes: 'ui-tooltip-red ui-tooltip-rounded ui-tooltip-shadow'
				}
			}
		);