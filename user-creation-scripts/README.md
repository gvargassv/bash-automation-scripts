User Creation Scripts
Scripts para creación automatizada de usuarios con permisos sudo en sistemas AIX y Linux.
🚀 Características

✅ Creación masiva de usuarios en servidores AIX
✅ Creación individual de usuarios en Linux/RHEL
✅ Configuración automática de permisos sudo sin contraseña
✅ Logging detallado de operaciones
✅ Validación de conectividad antes de ejecutar
✅ Manejo robusto de errores

📋 Requisitos
Para AIX (create_users_aix_sudo.sh)

Sistema operativo: Linux/Unix con acceso SSH a servidores AIX
Dependencias: expect, ssh
Permisos: Usuario con sudo o acceso root en servidores objetivo

Para Linux (create_user_linux_sudo.sh)

Sistema operativo: RHEL 8/9, CentOS, Rocky Linux
Permisos: Ejecutar como root o con sudo

📦 Instalación

Clonar el repositorio:

bashgit clone https://github.com/tu-usuario/user-creation-scripts.git
cd user-creation-scripts

Dar permisos de ejecución:

bashchmod +x *.sh

Instalar dependencias (para script AIX):

bash# Ubuntu/Debian
sudo apt-get install expect

# RHEL/CentOS
sudo yum install expect
🔧 Uso
Script AIX - Creación masiva
bash./create_users_aix_sudo.sh -u newuser -p 'MyP@ss' -s root -w 'RootPass' -f servers.txt
Script Linux - Creación individual
bashsudo ./create_user_linux_sudo.sh adminuser
📖 Documentación

Ejemplos detallados
Solución de problemas

🔒 Seguridad

⚠️ IMPORTANTE: Nunca hardcodees contraseñas en los scripts
🔐 Utiliza variables de entorno o archivos de configuración seguros
🛡️ Revisa siempre los logs generados
🔍 Valida la sintaxis de sudoers automáticamente

📝 Logs
Los logs se generan automáticamente en el directorio logs/ con formato:

user_creation_YYYYMMDD_HHMMSS.log

🤝 Contribuir

Fork el proyecto
Crea una rama para tu feature (git checkout -b feature/AmazingFeature)
Commit tus cambios (git commit -m 'Add some AmazingFeature')
Push a la rama (git push origin feature/AmazingFeature)
Abre un Pull Request

📄 Licencia
Este proyecto está bajo la Licencia MIT. Ver LICENSE para más detalles.
⚠️ Disclaimer
Estos scripts modifican configuraciones críticas del sistema. Úsalos bajo tu propia responsabilidad y siempre en un ambiente de pruebas primero.
