        $('.tipLocation').qtip
        (
                {
                        content: 
                        {
                                text: 'Select the home location of the associate or team that is being nominated.',
                                title: 
                                {
                                        text: function(api) 
                                        {
                                                return $(this).attr('alt');
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
        $('.tipType').qtip
        (
                {
                        content: 
                        {
                                text: 'Select the type of nomination, either an individual, a team or a group of associates.',
                                title: 
                                {
                                        text: function(api) 
                                        {
                                                return $(this).attr('alt');
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
        $('.tipNominee').qtip
        (
                {
                        content: 
                        {
                                text: 'Either select a nominee from the dropdown list if doing an individual nomination or enter the members of the team or group.',
                                title: 
                                {
                                        text: function(api) 
                                        {
                                                return $(this).attr('alt');
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
        $('.tipNominator').qtip
        (
                {
                        content: 
                        {
                                text: 'Select the associate making this nomination from the dropdown list.',
                                title: 
                                {
                                        text: function(api) 
                                        {
                                                return $(this).attr('alt');
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
        $('.tipStory').qtip
        (
                {
                        content: 
                        {
                                text: 'Enter the details of the event, effort, project, etc that inspired you to nominate the associate, team or group.',
                                title: 
                                {
                                        text: function(api) 
                                        {
                                                return $(this).attr('alt');
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
        $('.tipCancel').qtip
        (
                {
                        content: 
                        {
                                text: 'Cancel your nomination and close this window, the information entered will not be submitted for consideration.',
                                title: 
                                {
                                        text: function(api) 
                                        {
                                                return $(this).attr('alt');
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
        $('.tipReset').qtip
        (
                {
                        content: 
                        {
                                text: 'Reset the information entered on this page to the default values displayed when the form is initially loaded.',
                                title: 
                                {
                                        text: function(api) 
                                        {
                                                return $(this).attr('alt');
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
        $('.tipSubmit').qtip
        (
                {
                        content: 
                        {
                                text: 'Submit this nomination form for consideration for the Chip of the Week.',
                                title: 
                                {
                                        text: function(api) 
                                        {
                                                return $(this).attr('alt');
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
    
        $(document).ready(function()
        {
                $("form#chipNominationForm").submit(function()
                {
                        $("#chipNominationForm").validationEngine('init');
                        $("#chipNominationForm").validationEngine('attach');
        
                        if(!($("#chipNominationForm").validationEngine('validate')))
                        {
                                return false;
                        }
                        
                        var loc       = $('#chipLocation').attr('value');
                        var typx      = $('#chipType').attr('value');
                        var nominee   = $('#chipNominee').attr('value');
                        var nominator = $('#chipNominator').attr('value');
                        var theStory  = $('#chipStory').attr('value'); 
                        
                        $.ajax(
                        {
                            type: "GET",
                            url: "../cgi-bin/prcssChipNominations.pl", 
                            contentType: "application/json; charset=utf-8",
                            dataType: "json",
                            data: "action=add&loc=" + loc + "&type=" + typx + "&nominee=" + nominee + "&nominator=" + nominator + "&story=" + theStory,
                            error:
                                function(XMLHttpRequest, textStatus, errorThrown)
                                {
                                        $('div#chipResult').text("responseText: " + XMLHttpRequest.responseText + ", textStatus: " + textStatus + ", errorThrown: " + errorThrown);
                                        $('div#chipResult').addClass("formErrors");
                                        $('div#loginResult').fadeIn(); 
                                        return false;
                                }, 
                            success:
                                function(data)
                                {
                                        if (data.error)
                                        { 
                                                $('div#chipResult').text("Your nomination was not submitted successfully, please try again.");
                                                $('div#chipResult').addClass("textRed");
                                                $('div#chipResult').addClass("textItalics");
                                                $('#logUserName').addClass("formErrors");
                                                $('div#loginResult').fadeIn(); 
                                                return false;
                                        } 
                                        else
                                        {
                                                setTimeout("selfClose()", 1000);
                                                alert("Congratulations, your nomination has been submitted for review.")
                                                return false;
                                        } 
                                } 
                        }); // ajax
                        return false;        
                });
        });
        
        function selfClose()
        {
                self.close();      
        };
