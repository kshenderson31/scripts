        var viewportwidth  = document.getElementsByTagName('body')[0].clientWidth;
        var viewportheight = document.getElementsByTagName('body')[0].clientHeight;
        
        invokeHoverAccordionMenu(".accordion");	
        blurLinks();
        
        $(document).ready(function()
        {
                loadHTML(11, "splashMrJimmySection");
                
                loadHTML(1, "splashExecSection");
                loadHTML(2, "splashMissionSection");
                loadHTML(3, "splash4PSection");
                loadHTML(4, "splashLEADSection");
                loadHTML(5, "splashFirstSection");
                loadHTML(6, "splashThreeSection");
                loadHTML(7, "splashCALMSection");
                loadHTML(8, "splashTRIFICSection");
                loadHTML(9, "splashInnovationSection");
                loadNews("tps", 5);
                loadEvents();
                
                loadSurveyWindow();
                loadAnniversaries();
                loadBirthdays();
                
                return false;
        });
        
        function setBackGroundColor(domElement, newColor)
        {
                var $myElement = document.getElementById(domElement);
                $myElement.style.backgroundColor = "white";
                $myElement.style.opacity = 1;
                $myElement.style.filter = "alpha(opacity=100)";
        }
        
        function resetBackGroundColor(domElement, newColor)
        {
                var $myElement = document.getElementById(domElement);
                $myElement.style.backgroundColor = "white";
                $myElement.style.opacity = 0.50;
                $myElement.style.filter = "alpha(opacity=50)";
        }

        var random_images = [];
        getImageFileNames("images/locations", random_images);
        
        var path="images/locations/";
        var i = 0;
        
        var rotateBg = setInterval(function()
                        {
                                var picSource = path + random_images[rand(random_images.length)];
                                $('body').smartBackgroundImage(picSource); 
                        }, 30000);
        
        function getImageFileNames(directory, randomImages)
        {	
                $.ajax(
                {
                    type: "GET",
                    url: "../cgi-bin/getFilesInDirectory.pl", 
                    contentType: "application/json; charset=utf-8",
                    dataType: "json",
                    data: "dir=" + directory,
                    error:
                        function(XMLHttpRequest, textStatus, errorThrown)
                        {
                                /*
                                ###
                                # To do: Set a default image to load when the load of image files fails
                                #
                                */
                                /*alert("Error encountered 1 |" + XMLHttpRequest + "|" + textStatus + "|" + errorThrown + "|");*/
                                return false;
                        }, 
                    success:
                        function(data)
                        {
                                if (data.error)
                                {
                                        return false;
                                } 
                                else
                                {
                                        var myArray = eval(data.filenames);
                                        for (var i = 0; i < myArray.length; i++)
                                        {
                                                random_images[i]= myArray[i];
                                        }
                                        /*return myArray;*/
                                        return true;
                                } 
                        } 
                }); // ajax
        }

        /* random number generator */
        function rand(n)
        {
            return ( Math.floor ( Math.random ( ) * n ) );
        }

        /* Custom onload function */
        function addLoadEvent(func)
        {
                var oldonload = window.onload;
                if (typeof window.onload != 'function')
                {
                        window.onload = func;
                }
                else
                {
                        window.onload = function()
                        {
                                oldonload();
                                func();
                        }
                }
        }
        
        $.fn.smartBackgroundImage = function(url)
        {
                var t = this; 
                //create an img so the browser will download the image: 
                $('<img />') 
                .attr('src', url)
                .attr('width', viewportwidth)
                .attr('height', viewportheight)
                .load(function(){ //attach onload to set background-image 
                t.each(function(){  
                $(this).css('backgroundImage', 'url('+url+')' ); 
                }); 
                }); 
                return this; 
                } 

        /* trigger onload */
        /*addLoadEvent(ChangeCSSBgImg);*/ 

$(document).ready(function()
{
        $("form#splashSurveyForm").submit(function()
        {
                $("#splashSurveyForm").validationEngine('init');
                $("#splashSurveyForm").validationEngine('attach');

                if(!($("#splashSurveyForm").validationEngine('validate')))
                {
                        return false;
                }
                
                var ans = $('#splashAnswers').attr('value');
                var cmt = $('#splashComments').attr('value');
                
                $.ajax(
                {
                    type: "GET",
                    url: "../cgi-bin/prcssSurveys.pl", 
                    contentType: "application/json; charset=utf-8",
                    dataType: "json",
                    data: "action=post&r=" + ans + "&c=" + cmt,
                    timeout: 5000,
                    statusCode:
                        {
                                500: function()
                                {
                                        $('div#Question').text("An error has been encountered recording your response, please try in a few minutes.");
                                        $('div#surveyMessage').addClass("textRed");
                                        $('div#surveyMessage').addClass("textItalics");
                                }
                        },
                    error:
                        function(XMLHttpRequest, textStatus, errorThrown)
                        {
                                $('div#Question').text("An error has been encountered recording your response, please try in a few minutes.");
                                $('div#surveyMessage').addClass("textRed");
                                $('div#surveyMessage').addClass("textItalics");
                                $('div#surveyMessage').fadeIn(); 
                                return false;
                        }, 
                    success:
                        function(data)
                        {
                                if (data.error)
                                { 
                                        $('div#surveyMessage').text("Your survey response was not recorded.");
                                        $('div#surveyMessage').addClass("textRed");
                                        $('div#surveyMessage').addClass("textItalics");
                                        $('div#surveyMessage').fadeIn(); 
                                        return false;
                                } 
                                else
                                {
                                        loadSurveyWindow("Your survey response has been recorded.");
                                        return false;
                                } 
                        } 
                }); // ajax
                return false;        
        });
});

function loadSurveyWindow(msgText)
{       
        $.ajax(
        {
            type: "GET",
            url: "../cgi-bin/prcssSurveys.pl", 
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            data: "action=get",
            error:
                function(XMLHttpRequest, textStatus, errorThrown)
                {
                        $('div#Question').text("responseText: " + XMLHttpRequest.responseText + ", textStatus: " + textStatus + ", errorThrown: " + errorThrown);
                        $('div#surveyMessage').addClass("textRed");
                        $('div#surveyMessage').addClass("textItalics");
                        return false;
                }, 
            success:
                function(data)
                {
                        if (data.error)
                        { 
                                $('div#surveyMessage').text("An error has been encountered while loading the list of locations.");
                                $('div#surveyMessage').addClass("textRed");
                                $('div#surveyMessage').addClass("textItalics");
                                
                                return false;
                        } 
                        else
                        {
                                if (data.success)
                                {
                                       
                                        var options = '<option value="">Select your response</option>';
                                        for (var i = 0; i < data.answers.length; i++)
                                        {
                                                options += '<option value="' + data.answers[i].optionValue + '">' + data.answers[i].optionDisplay + '</option>';
                                        }
                                        
                                        var srvyQuestion = document.getElementById("splashQuestion");
                                        srvyQuestion.innerHTML = data.qstn;
                                        
                                        $("select#splashAnswers").html(options);
                                        var srvyAnswers = document.getElementById("splashAnswers");
                                        srvyAnswers.style.visibility = "visible";
                                        
                                        
                                        
                                        var srvyForm = document.getElementById("splashSurveyForm");
                                        srvyForm.style.visibility = "visible";
                                
                                        return true;
                                }
                                else
                                {
                                        if(data.taken)
                                        {
                                                $("div#splashSurveyArea").html(data.taken);
                                                $('div#surveyMessage').text(msgText);
                                                $('div#surveyMessage').addClass("textRed");
                                                $('div#surveyMessage').addClass("textItalics");
                                        }
                                        else
                                        {
                                                $("div#splashSurveyArea").html("&nbsp;There is not an active survey at this time.");
                                        }
                                }
                        } 
                } 
        }); // ajax
        
        return false;
};

function loadAnniversaries()
{       
        $.ajax(
        {
            type: "GET",
            url: "../cgi-bin/getEmployeesAnniversaries.pl", 
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            data: "",
            error:
                function(XMLHttpRequest, textStatus, errorThrown)
                {
                        $('div#Question').text("An error has been encountered trying to record your response [" + errorThrown + "]");
                        $('div#surveyMessage').addClass("textRed");
                        $('div#surveyMessage').addClass("textItalics");
                        return false;
                }, 
            success:
                function(data)
                {
                        var cnt = 0;
                        var lastDate = '';
                        var options = '';
                        
                        for (var i = 0; i < data.anniv.length; i++)
                        {
                                if(data.anniv[i].yrs > 0)
                                {
                                        if(lastDate != data.anniv[i].dt)
                                        {
                                                if(cnt != 0)
                                                {
                                                        options += '</ul><br />';
                                                }
                                                options += '<ul style="margin-left:5px;"><span style="font-weight:bold;">'+data.anniv[i].dt+'</span><br />';
                                        }
                                        
                                        options += '<li>'+data.anniv[i].ln+', '+data.anniv[i].fn+'&nbsp;&nbsp;&nbsp;['+data.anniv[i].yrs+' years]</li>';
                                        
                                        lastDate = data.anniv[i].dt;
                                        
                                        cnt++;
                                }
                        }
                        
                        options += '</ul>';
                        
                        if(cnt == 0)
                        {
                                options = "<p style='margin-left:5px; margin-top:5px; margin-bottom:5px;'>There are no anniversaries to display."
                        }

                        $("div#splashAnniv").html(options);
                        
                        cnt = 0;
                        options = '';
                        lastdate = '';
                        
                        for (var i = 0; i < data.anniv.length; i++)
                        {
                                if(data.anniv[i].yrs == 0)
                                {
                                        if(lastDate != data.anniv[i].dt)
                                        {
                                                if(cnt != 0)
                                                {
                                                        options += '</ul><br />';
                                                }
                                                options += '<ul style="margin-left:5px;"><span style="font-weight:bold;">'+data.anniv[i].dt+'</span><br />';
                                        }
                                        
                                        options += '<li>'+data.anniv[i].ln+', '+data.anniv[i].fn+'&nbsp;&nbsp;&nbsp;['+data.anniv[i].loc+']</li>';
                                        
                                        lastDate = data.anniv[i].dt;
                                        
                                        cnt++;
                                }
                        }
                        
                        options += '</ul>';
                        
                        if(cnt == 0)
                        {
                                options = "<p style='margin-left:5px; margin-top:5px; margin-bottom:5px;'>There are no new hires to display."
                        }
                        
                        $("div#splashHires").html(options);

                        return true;
                } 
        }); // ajax
        
        return false;
};

function loadBirthdays()
{       
        $.ajax(
        {
            type: "GET",
            url: "../cgi-bin/getEmployeesBirthdays.pl", 
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            data: "",
            error:
                function(XMLHttpRequest, textStatus, errorThrown)
                {
                        $('div#Question').text("responseText: " + XMLHttpRequest.responseText + ", textStatus: " + textStatus + ", errorThrown: " + errorThrown);
                        $('div#surveyMessage').addClass("textRed");
                        $('div#surveyMessage').addClass("textItalics");
                        return false;
                }, 
            success:
                function(data)
                {
                        var cnt = 0;
                        var lastDate = '';
                        var options = '';
                        
                        for (var i = 0; i < data.bday.length; i++)
                        {
                                if(data.bday[i].yrs > 0)
                                {
                                        if(lastDate != data.bday[i].dt)
                                        {
                                                if(cnt != 0)
                                                {
                                                        options += '</ul><br />';
                                                }
                                                options += '<ul style="margin-left:5px;"><span style="font-weight:bold;">'+data.bday[i].dt+'</span><br />';
                                        }
                                        
                                        options += '<li>'+data.bday[i].ln+', '+data.bday[i].fn+'&nbsp;&nbsp;&nbsp;['+data.bday[i].loc+']</li>';
                                        
                                        lastDate = data.bday[i].dt;
                                        
                                        cnt++;
                                }
                        }
                        
                        options += '</ul>';
                        
                        if(cnt == 0)
                        {
                                options = "<p style='margin-left:5px; margin-top:5px; margin-bottom:5px;'>There are no birthdays to display."
                        }

                        $("div#splashBirthdays").html(options);

                        return true;
                } 
        }); // ajax
        
        return false;
};

function loadHTML(key, domElement)
{       
        $.ajax(
        {
            type: "GET",
            url: "../cgi-bin/getHTML.pl", 
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            data: "key="+key,
            error:
                function(XMLHttpRequest, textStatus, errorThrown)
                {
                        $('div#Question').text("responseText: " + XMLHttpRequest.responseText + ", textStatus: " + textStatus + ", errorThrown: " + errorThrown);
                        $('div#surveyMessage').addClass("textRed");
                        $('div#surveyMessage').addClass("textItalics");
                        return false;
                }, 
            success:
                function(data)
                {
                    $("div#"+domElement).html(data.html);
                    return true;
                } 
        }); // ajax
        
        return false;
};

function loadNews(catg, lim)
{       
        $.ajax(
        {
            type: "GET",
            url: "../cgi-bin/getNews.pl", 
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            data: "catg="+catg+"&limit="+lim,
            error:
                function(XMLHttpRequest, textStatus, errorThrown)
                {
                        $('div#splashNewsSection').text("An error has been encountered loading the news feeds. [" + errorThrown + "]");
                        
                        return false;
                }, 
            success:
                function(data)
                {
                        var options = '';
                        var cnt = 0;
                        
                        for (var i = 0; i < data.news.length; i++)
                        {
                                if(cnt > 0)
                                {
                                        options += '<div class=smSpacer></div>';
                                        options += '<div class=smDivider></div>';
                                        options += '<div class=smSpacer></div>';
                                        
                                }
                                options += '<div class=newsStory>';
                                options += '<div class=newsHeadline>'+data.news[i].ttl+'</div>';
                                options += '<div class=newsByline>'+data.news[i].src+', '+data.news[i].pub+'</div>';
                                
                                if((data.news[i].cpy != "None") && (data.news[i].auth != "Unknown"))
                                {
                                        var text = '';
                                        if(data.news[i].cpy != "None")
                                        {
                                            text = data.news[i].cpy;
                                        }
                                        if(data.news[i].auth != "Unknown")
                                        {
                                                if(data.news[i].cpy != "None")
                                                {
                                                        text += ', ';
                                                }
                                                text += data.news[i].auth;
                                        }
                                        options += '<div class=newsByline>'+text+'</div>';        
                                }
                                
                                
                                options += '<div class=smSpacer></div>';
                                options += '<div class=newsBody>'+unescape(data.news[i].story)+'</div>';
                                options += '</div>';
                                
                                cnt++;
                                
                        }
                        
                        if(cnt == 0)
                        {
                                options = '<div class=newsStory>There are no recent news stories available at this time</div>'
                        }
                        $("div#splashNewsSection").html(options);
        
                        return true;
                } 
        }); // ajax
        
        return false;
};

function loadEvents()
{       
        $.ajax(
        {
            type: "GET",
            url: "../cgi-bin/getEvents.pl", 
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            data: "",
            error:
                function(XMLHttpRequest, textStatus, errorThrown)
                {
                        $('div#splashEventsSection').text("An error has been encountered loading the news feeds. [" + errorThrown + "]");    
                        return false;
                }, 
            success:
                function(data)
                {
                        var options = '';
                        var cnt = 0;
                        var lastDate = '';
                        
                        for (var i = 0; i < data.event.length; i++)
                        {
                                options += '<div class=splashEvent>';
                                
                                if(lastDate != data.event[i].dt)
                                {
                                        options += '<div class=splashEventDate>'+data.event[i].dt+'</div>';
                                }
                        
                                options += '<div class=splashEventDescription>'+data.event[i].desc+'</div>';
                                
                                if(data.event[i].loc != "")
                                {
                                        options += '<div class=splashEventDetails>'+data.event[i].loc+', '+data.event[i].btm+' - '+data.event[i].etm+'</div>';
                                }
                                else
                                {
                                        options += '<div class=splashEventDetails>'+data.event[i].btm+' - '+data.event[i].etm+'</div>';        
                                }
                                
                                options += '<div class=splashEventDetails>'+data.event[i].org+'</div>';
                                
                                if(data.event[i].cmt != "")
                                {
                                        options += '<div class=splashEventComments>'+data.event[i].cmt+'</div>';
                                }
                                
                                options += '</div>';
                                
                                lastDate = data.event[i].dt;
                                cnt++;
                        }
                        
                        if(cnt == 0)
                        {
                                options = '<div class=newsStory>There are no recent news stories available at this time</div>'
                        }
                        else
                        {
                                var myElement = document.getElementById("splashEventsWindow");
                                myElement.style.height = "250px";
                                myElement.style.overflow = "auto";
                        }
                        
                        $("div#splashEventsWindow").html(options);
                        return true;
                } 
        }); // ajax
        
        return false;
};
