using Microsoft.Owin;
using Owin;

[assembly: OwinStartupAttribute(typeof(simple2tierweb.Startup))]
namespace simple2tierweb
{
    public partial class Startup {
        public void Configuration(IAppBuilder app) {
            ConfigureAuth(app);
        }
    }
}
