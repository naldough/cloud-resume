const counter = document.querySelector(".counter-number");
async function updateCounter() {
    let response = await fetch("https://w6zy7vteztjn55oby2lf56deiy0kdfoa.lambda-url.us-east-2.on.aws/");
    let data = await response.json();
    counter.innerHTML = ` This page has ${data} Views!`;
}

updateCounter();