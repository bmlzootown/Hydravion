# Hydravion
**Unofficial Floatplane client for Roku devices. This project is NOT associated with Floatplane Media (floatplane.com).**


Having issues? Have feedback? Join the [Discord server](https://discord.gg/4xKDGz5M5B)!


The non-certified version can be added via access code [5KZLCLZ](https://my.roku.com/add/5KZLCLZ), or you can sideload the source itself. The non-certified version does ***not*** require a reCAPTCHA token.


# Login
Upon entering one's Floatplane credentials, the user will be prompted to browse to https://bmlzoo.town/hydravion on another device where they will be instructed on how to obtain a one-time reCAPTCHA token that is necessary for login. The token can be obtained from [floatplane.com/login](https://www.floatplane.com/login) by opening the console and running the following command (while *not* logged in):
```javascript
grecaptcha.execute('6LfwnJ0aAAAAANTkEF2M1LfdKx2OpWAxPtiHISqr', { action:'validate_captcha' }).then(console.log)
```
