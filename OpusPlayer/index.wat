<!DOCTYPE html>
<html>
    <head>
        <title>OpusPlayer</title>
        <style type = "text/css">
            table {
                color : black;
                background : #fff;
                border : 1px solid #B4B4B4;
                font : bold 24px Helvetica;
                padding : 5;
                color : #666;
                border-collapse : collapse;
                margin : 40px 10px 1px 10px;
                vertical-align : middle;
                text-align : center;
                -webkit-border-radius : 8px;
                width : 98%;
            }
            table td {
                padding : 5px 10px 5px 10px;
            }
            input {
                font : bold 14px Helvetica;
            }
        </style>

        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <meta name="Description" content="Tells what OpusPlayer is playing" />
        <meta name="keywords" content="music,OpusPlayer" />
        <meta name="Author" content="Chris van Engelen" />
        <meta name="copyright" content="2013" />
        <meta http-equiv="imagetoolbar" content="false" />

        <!-- Apple Web App -->
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <meta name="viewport" content = "width = device-width, initial-scale = 0.8, maximum-scale = 2, user-scalable = yes" />
        <!-- <link rel="apple-touch-icon-precomposed" href="beethoven.png"/> -->
        <link rel="apple-touch-icon" href="beethoven.png"/>
    </head>
    <body>
        <table border="0">
            <tr>
                <td colspan="3"><%print composerOpus.HTML></td>
            </tr>
            <tr>
                <td colspan="3"><%print opusPart.HTML></td>
            </tr>
            <tr>
                <td colspan="3"><%print artist.HTML></td>
            </tr>
            <tr>
                <td>
                    <form action="refresh" method="post">
                        <input type="submit" value="Refresh">
                    </form>
                </td>
                <td>
                    <form action="playOrPause" method="post">
                        <input type="submit" value="Play/Pause">
                    </form>
                </td>
                <td>
                    <form action="playNextOpus" method="post">
                        <input type="submit" value="Next Opus">
                    </form>
                </td>
            </tr>
        </table>
    </body>
</html>