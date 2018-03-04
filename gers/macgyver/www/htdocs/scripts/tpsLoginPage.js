    /* invokeFormValidationEngine("#loginForm"); */

    $('.tipUserName').qtip
    (
            {
                    content: 
                    {
                            text: 'Enter the username that is used to logon to your workstation each morning, commonly referred to as your Windows user name.',
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
    $('.tipPassWord').qtip
    (
            {
                    content: 
                    {
                            text: 'Enter the password that is used to logon to your workstation each morning, commonly referred to as your Windows password.',
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
                            text: 'Cancel your logon to The Paradies Shops\' portal and close the current window.',
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
                            text: 'Reset your current password.  A serious of challenge questions will be presented to confirm your identity.',
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
    $('.tipLogon').qtip
    (
            {
                    content: 
                    {
                            text: 'Submit the supplied username and password to authentication, and log onto The Paradies Shops\' portal.',
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
                $("form#loginForm").submit(function()
                {
                        $("#loginForm").validationEngine('init');
                        $("#loginForm").validationEngine('attach');
        
                        if(!($("#loginForm").validationEngine('validate')))
                        {
                                return false;
                        }
                        
                        var username = $('#logUserName').attr('value'); 
                        var password = $('#logPassWord').attr('value');
                        
                        $('#logUserName').value = username; 
                        
                        $.ajax(
                        {
                            type: "GET",
                            url: "../cgi-bin/tpsAuthentication.pl", 
                            contentType: "application/json; charset=utf-8",
                            dataType: "json",
                            data: "token=" + username + "&key=" + password,
                            error:
                                function(XMLHttpRequest, textStatus, errorThrown)
                                {
                                        $('div#loginResult').text("responseText: " + XMLHttpRequest.responseText + ", textStatus: " + textStatus + ", errorThrown: " + errorThrown);
                                        $('div#loginResult').addClass("formErrors");
                                        return false;
                                }, 
                            success:
                                function(data)
                                {
                                        if (data.error)
                                        { 
                                                $('div#loginResult').text("The username or password you supplied is not correct");
                                                $('div#loginResult').addClass("textRed");
                                                $('div#loginResult').addClass("textItalics");
                                                $('#logUserName').addClass("formErrors");
                                                $('#logPassWord').addClass("formErrors");
                                                return false;
                                        } 
                                        else
                                        { 
                                                self.close();
                                                window.open('../cgi-bin/tpsPages.pl?page=0&appl=DFLT','_blank', 'top=0, left=0,fullscreen=no,status=yes,scrollbars=auto,menubar=yes,resizable=no,width='+parent.screen.width+',height='+parent.screen.height);
                                                return true;
                                        } 
                                } 
                        }); // ajax
                        
                        $('div#loginResult').fadeIn(); 
                        return false;
                 });
        });
        
        function resetLoginForm()
        {
                $('#logUserName').value = "";
                $('#logPassWord').value = "";
                $('div#loginResult').text("");
                $('div#loginResult').removeClass("textRed");
                $('div#loginResult').removeClass("textItalics");
                $('#logUserName').removeClass("formErrors");
                $('#logPassWord').removeClass("formErrors");
        }
    